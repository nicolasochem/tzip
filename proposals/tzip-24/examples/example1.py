import smartpy as sp

# Import from URL
meta_tx_contract_url = "https://ipfs.io/ipfs/QmYwxHw4hzaMwvpLEnBKmUFeu322wo3NUXEKYL27jVffA9"
MetaTxnTemplate = sp.io.import_script_from_url(url=meta_tx_contract_url)

# Import from smartPy named contract
# MetaTxnTemplate = sp.io.import_stored_contract(name="MetaTxnTemplate")


class Quote(sp.Contract):
    def __init__(self):
        self.sp_sender = sp.address("tz123")
        self.init(
            quote="",
            updater=sp.address("tz123"),
        )

    @sp.entry_point
    def set_quote(self, new_quote):
        self.data.quote = new_quote
        self.data.updater = self.sp_sender


@sp.add_test(name="QuoteMetaTransaction")
def test():
    alice = sp.test_account("Alice")
    bob = sp.test_account("Bob")
    owner = sp.test_account("Owner")

    chainId = sp.chain_id_cst("0x9caecab9")

    # Create test scenario
    scenario = sp.test_scenario()
    scenario.table_of_contents()

    # Display test accounts
    scenario.h1("Accounts")
    scenario.show([alice, bob, owner])

    FIVE_MINS = 5

    # Generate and register Quote meta transaction contract
    scenario.h1("Quote DApp using Native Meta Transaction")
    quote = Quote()
    scenario.register(quote, show=False)
    quote_with_meta_tx = MetaTxnTemplate.MetaTransaction(base_contract=quote, owner=owner.address)
    scenario += quote_with_meta_tx

    # Test Case - 1
    scenario.h3("Alice sends a set quote request on her own")
    quote_value = "The biggest adventure you can ever take is to live the life of your dreams - Oprah"
    scenario += quote_with_meta_tx.set_quote(
        params=quote_value,
        meta_tx_params=sp.none
    ).run(sender=alice, chain_id=chainId, now=sp.timestamp(0))
    scenario.verify_equal(
        quote_with_meta_tx.data.base_state.quote, quote_value)
    scenario.verify_equal(
        quote_with_meta_tx.data.base_state.updater, alice.address)
        
    # Test case - 2 - Update default_expiry
    scenario.h3("Owner updates the default expiry")
    scenario += quote_with_meta_tx.set_default_expiry(
        sp.to_int(100)
    ).run(sender=owner, chain_id=chainId, now=sp.timestamp(0))
    scenario.verify_equal(
        quote_with_meta_tx.data.default_expiry, 100)
    
    # Test case - 3 - Update default_expiry, non-owner
    scenario.h3("Alice (non-owner) tries updating the default expiry")
    scenario += quote_with_meta_tx.set_default_expiry(
        sp.to_int(100)
    ).run(sender=alice, chain_id=chainId, now=sp.timestamp(0), valid=False)
    
    # Test case - 4 - Update max_expiry
    scenario.h3("Owner updates the max expiry")
    scenario += quote_with_meta_tx.set_max_expiry(
        sp.to_int(89000)
    ).run(sender=owner, chain_id=chainId, now=sp.timestamp(0))
    scenario.verify_equal(
        quote_with_meta_tx.data.max_expiry, 89000)
    
    # Test case - 5 - Update max_expiry, non-owner
    scenario.h3("Bob (non-owner) tries updating the max expiry")
    scenario += quote_with_meta_tx.set_max_expiry(
        sp.to_int(1000000)
    ).run(sender=bob, chain_id=chainId, now=sp.timestamp(0), valid=False)
    
    # Test Case - 6
    scenario.h3("Bob sends a Quote on behalf of Alice")
    quote_value = "Building a mission and building a business go hand in hand - Zuckerberg"
    paramHash = sp.blake2b(sp.pack(quote_value))
    tx_expiry = sp.timestamp(1623025577).add_minutes(FIVE_MINS)
    
    data = sp.pack(sp.record(
        chain_id=chainId,
        contract_addr=quote_with_meta_tx.address,
        counter=1,
        tx_expiry_time=sp.some(tx_expiry),
        param_hash=paramHash
    ))
    sig = sp.make_signature(alice.secret_key, data, message_format='Raw')

    meta_tx_params = sp.record(
        pub_key=alice.public_key,
        counter=1,
        sig=sig,
        tx_expiry_time=sp.some(tx_expiry)
    )
    scenario += quote_with_meta_tx.set_quote(
        params=quote_value,
        meta_tx_params=sp.some(meta_tx_params)
    ).run(sender=bob, chain_id=chainId, now=sp.timestamp(1623025577))

    scenario.verify_equal(
        quote_with_meta_tx.data.base_state.quote, quote_value)
    scenario.verify_equal(
        quote_with_meta_tx.data.base_state.updater, alice.address)

    # Test Case - 7
    # replay attack
    scenario.h3(
        "Bob sends the Quote he sent previously on behalf of Alice, replay attack")
    meta_tx_params = sp.record(
        pub_key=alice.public_key,
        counter=1,
        sig=sig,
        tx_expiry_time=sp.some(tx_expiry)
    )
    scenario += quote_with_meta_tx.set_quote(
        params=quote_value,
        meta_tx_params=sp.some(meta_tx_params)
    ).run(sender=bob, chain_id=chainId, now=sp.timestamp(1623025791), valid=False)

    # Test Case - 8
    # pubkey mismatch
    scenario.h3("Alice signs an invalid quote request, pubKey mismatch")
    quote_value = "Failure is simply the opportunity to begin again, this time more intelligently - Ford"
    paramHash = sp.blake2b(sp.pack(quote_value))
    tx_expiry = sp.timestamp(1623025846).add_minutes(FIVE_MINS)
    data = sp.pack(sp.record(
        chain_id=chainId,
        contract_addr=quote_with_meta_tx.address,
        counter=2,
        tx_expiry_time=sp.some(tx_expiry),
        param_hash=paramHash
    ))
    sig = sp.make_signature(alice.secret_key, data, message_format='Raw')

    meta_tx_params = sp.record(
        pub_key=bob.public_key,
        counter=2,
        sig=sig,
        tx_expiry_time=sp.some(tx_expiry)
    )
    scenario += quote_with_meta_tx.set_quote(
        params=quote_value,
        meta_tx_params=sp.some(meta_tx_params)
    ).run(sender=bob, chain_id=chainId, now = sp.timestamp(1623025846), valid=False)

    # Test Case - 9
    # chainId mismatch
    scenario.h3("Alice signs a invalid quote request, chainId mismatch")
    quote_value = "He who is not everyday conquering some fear has not learned the secret of life - R W Emerson"
    paramHash = sp.blake2b(sp.pack(quote_value))
    tx_expiry = sp.timestamp(1623025895).add_minutes(FIVE_MINS)
    data = sp.pack(sp.record(
        chain_id=1,
        contract_addr=quote_with_meta_tx.address,
        counter=2,
        tx_expiry_time=sp.some(tx_expiry),
        param_hash=paramHash
    ))
    sig = sp.make_signature(alice.secret_key, data, message_format='Raw')

    meta_tx_params = sp.record(
        pub_key=alice.public_key,
        counter=2,
        sig=sig,
        tx_expiry_time=sp.some(tx_expiry)
    )
    scenario += quote_with_meta_tx.set_quote(
        params=quote_value,
        meta_tx_params=sp.some(meta_tx_params)
    ).run(sender=bob, chain_id=chainId, now = sp.timestamp(1623025895), valid=False)

    # Test Case - 10
    # counter mismatch
    scenario.h3("Alice signs an invalid quote request, counter mismatch")
    quote_value = "An entrepreneur is someone who jumps off a cliff and builds a plane on the way down - R Hoffman"
    paramHash = sp.blake2b(sp.pack(quote_value))
    tx_expiry = sp.timestamp(1623025925).add_minutes(FIVE_MINS)
    data = sp.pack(sp.record(
        chain_id=chainId,
        contract_addr=quote_with_meta_tx.address,
        counter=0,
        tx_expiry_time=sp.some(tx_expiry),
        param_hash=paramHash
    ))
    sig = sp.make_signature(alice.secret_key, data, message_format='Raw')

    meta_tx_params = sp.record(
        pub_key=alice.public_key,
        counter=0,
        sig=sig,
        tx_expiry_time=sp.some(tx_expiry)
    )
    scenario += quote_with_meta_tx.set_quote(
        params=quote_value,
        meta_tx_params=sp.some(meta_tx_params)
    ).run(sender=bob, chain_id=chainId, now = sp.timestamp(1623025925), valid=False)

    # Test Case - 11
    # contract address mismatch
    scenario.h3(
        "Alice signs an invalid quote request, contract address mismatch")
    quote_value = "I have not failed. I’ve just found 10,000 ways that won’t work - Edison"
    paramHash = sp.blake2b(sp.pack(quote_value))
    tx_expiry = sp.timestamp(1623025947).add_minutes(FIVE_MINS)
    data = sp.pack(sp.record(
        chain_id=chainId,
        contract_addr=sp.address("KT1CAPu1KdZEH2jdqz82NQztoWSf2Zn58MX4"),
        counter=2,
        tx_expiry_time=sp.some(tx_expiry),
        param_hash=paramHash
    ))
    sig = sp.make_signature(alice.secret_key, data, message_format='Raw')

    meta_tx_params = sp.record(
        pub_key=alice.public_key,
        counter=2,
        sig=sig,
        tx_expiry_time=sp.some(tx_expiry)
    )
    scenario += quote_with_meta_tx.set_quote(
        params=quote_value,
        meta_tx_params=sp.some(meta_tx_params)
    ).run(sender=bob, chain_id=chainId, now = sp.timestamp(1623025947), valid=False)


    # Test Case - 12
    # meta txn expiry
    scenario.h3(
        "Alice signs an invalid quote request, meta txn signature expired")
    quote_value = "I have not failed. I’ve just found 10,000 ways that won’t work - Edison"
    paramHash = sp.blake2b(sp.pack(quote_value))
    tx_expiry = sp.timestamp(1623025963).add_minutes(FIVE_MINS)
    data = sp.pack(sp.record(
        chain_id=chainId,
        contract_addr=quote_with_meta_tx.address,
        counter=2,
        tx_expiry_time=sp.some(tx_expiry),
        param_hash=paramHash
    ))
    sig = sp.make_signature(alice.secret_key, data, message_format='Raw')

    meta_tx_params = sp.record(
        pub_key=alice.public_key,
        counter=2,
        sig=sig,
        tx_expiry_time=sp.some(tx_expiry)
    )
    scenario += quote_with_meta_tx.set_quote(
        params=quote_value,
        meta_tx_params=sp.some(meta_tx_params)
    ).run(sender=bob, chain_id=chainId, now = tx_expiry.add_seconds(10), valid=False)
