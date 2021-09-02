import smartpy as sp

# Default expiry to 3600 secs i.e., 1 hour
default_expiry = sp.to_int(3600)
# Max expiry to 86400 secs i.e., 1 day
max_expiry = sp.to_int(86400)

TParams = sp.TRecord(
    pub_key=sp.TKey,
    sig=sp.TSignature,
    counter=sp.TNat,
    tx_expiry_time=sp.TOption(sp.TTimestamp)
)


# Access Control contract for updating default_expiry, max_expiry
class AccessControl(sp.Contract):
    def __init__(self, owner):
        self.init(
            owner=owner
        )

    def is_owner(self):
        sp.verify(sp.sender == self.data.owner, "ONLY_OWNER")

    @sp.entry_point
    def change_owner(self, new_owner):
        self.is_owner()
        self.data.owner = new_owner

# NOTE about the `sp_sender` variable
# sp_sender - Provides information about the current execution context, including the
# sender of the transaction. While these are generally available via
# sp.sender, they should not be accessed in such a direct
# manner, since when dealing with meta-transactions the account sending and
# paying for execution may not be the actual sender (as far as an application
# is concerned).


class MetaTransaction(sp.Contract, AccessControl):
    def __init__(self, base_contract, owner, default_expiry=default_expiry, max_expiry=max_expiry):
        self.base_contract = base_contract

        # TZIP-16 metadata
        metadata = {
            "version": "1.0.0",
            "description": (
                "This is a reference implementation of single-step meta txn,"
                + " a.k.a. TZIP-024, using SmartPy."
            ),
            "interfaces": ["TZIP-017", "TZIP-016", "TZIP-024"],
            "views": [self.GetCounter, self.GetDefaultExpiry, self.GetMaxExpiry]
        }
        self.init_metadata("metadata_base", metadata)

        self.init(
            owner=owner,
            # Keeps track of the last seen counter
            user_counter=sp.big_map(tkey=sp.TAddress, tvalue=sp.TNat),
            base_state=base_contract.data,
            default_expiry=default_expiry,
            max_expiry=max_expiry
        )

    def get_last_seen_counter(self, address):
        counter = sp.local("counter", 0)
        sp.if self.data.user_counter.contains(address):
            counter.value = self.data.user_counter[address]
        return counter.value

    def get_tx_expiry_time(self, tx_expiry_time):
        expires_at = sp.local("expires_at", sp.now)
        sp.if tx_expiry_time.is_some():
            expires_at.value = tx_expiry_time.open_some()
        sp.else:
            expires_at.value = sp.now.add_seconds(self.data.default_expiry)
        return expires_at.value

    def update_last_seen_counter(self, address, counter):
        self.data.user_counter[address] = counter

    @sp.offchain_view(doc="Fetch the user's last seen counter")
    def GetCounter(self, address):
        sp.result(self.get_last_seen_counter(address))

    @sp.entry_point
    def set_default_expiry(self, expiry):
        self.is_owner()
        sp.verify(expiry <= self.data.max_expiry,
                  "MAX_EXPIRY_TIME_LIMIT_EXCEEDED")
        self.data.default_expiry = expiry

    @sp.entry_point
    def set_max_expiry(self, expiry):
        self.is_owner()
        self.data.max_expiry = expiry

    @sp.offchain_view(doc="Fetch the default expiry for meta txn")
    def GetDefaultExpiry(self, address):
        sp.result(self.data.default_expiry)

    @sp.offchain_view(doc="Fetch the upper bound of expiry for meta txn")
    def GetMaxExpiry(self, address):
        sp.result(self.data.max_expiry)

    def get_address_from_pub_key(self, pub_key):
        return sp.to_address(sp.implicit_account(sp.hash_key(pub_key)))

    def check_meta_tx_validity(self, param_hash, counter, public_key, signature, tx_expiry_time):
        expires_at = self.get_tx_expiry_time(tx_expiry_time)
        sp.verify(sp.now <= expires_at, "META_TX_EXPIRED")
        sp.verify(expires_at <= sp.now.add_seconds(
            self.data.max_expiry), "MAX_EXPIRY_TIME_LIMIT_EXCEEDED")

        address = self.get_address_from_pub_key(public_key)
        last_seen_counter = self.get_last_seen_counter(address)
        data = sp.pack(
            sp.record(
                chain_id=sp.chain_id,
                contract_addr=sp.self_address,
                counter=counter,
                tx_expiry_time=tx_expiry_time,
                param_hash=param_hash
            )
        )
        sp.verify(counter > last_seen_counter, "COUNTER_MISMATCH")
        sp.verify(
            sp.check_signature(public_key, signature, data),
            "MISSIGNED"
        )
        self.update_last_seen_counter(address, counter)

    # Update the implementation of functions to add meta-tx support
    # Note: This fn. is invoked by smartpy only at compile time
    def buildExtraMessages(self):
        for (name, f) in self.base_contract.messages.items():
            def message(self, params):
                former_base_state = self.base_contract.data
                self.base_contract.data = self.data.base_state

                # Add sig and key, optional parameters
                sp.set_type(params.meta_tx_params, sp.TOption(TParams))
                # Original fn params
                ep_params = params.params

                sp_sender = sp.local("sp_sender", sp.sender)

                # Check if sig, key is present;
                # If so, validate meta_tx
                # Adjust sp_sender to the actual sender of meta tx
                sp.if params.meta_tx_params.is_some():
                    meta_tx_params = params.meta_tx_params.open_some()

                    pub_key = meta_tx_params.pub_key
                    signature = meta_tx_params.sig
                    counter = meta_tx_params.counter
                    tx_expiry_time = meta_tx_params.tx_expiry_time

                    sp_sender.value = self.get_address_from_pub_key(
                        pub_key)
                    param_hash = sp.blake2b(sp.pack(ep_params))
                    self.check_meta_tx_validity(
                        param_hash, counter, pub_key, signature, tx_expiry_time)

                self.base_contract.sp_sender = sp_sender.value

                # Original fn implementation
                f.addedMessage.f(self.base_contract, ep_params)
                self.base_contract.data = former_base_state

            self.addMessage(sp.entry_point(message, name))
