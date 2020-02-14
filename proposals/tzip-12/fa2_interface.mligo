type token_id =
  | Single
  | Multi of nat

type transfer = {
  from_ : address;
  to_ : address;
  token_id : token_id;
  amount : nat;
}

type transfer_param = transfer list

type custom_config_param = {
  entrypoint : address;
  tag : string;
}

type permission_policy_config =
  | Operators_config of address
  | Whitelist_config of address
  | Custom_config of custom_config_param

type balance_request = {
  owner : address;
  token_id : token_id;  
}

type balance_response = {
  request : balance_request;
  balance : nat;
}

type balance_of_param = {
  balance_requests : balance_request list;
  balance_view : (balance_response list) contract;
}

type total_supply_response = {
  token_id : token_id;
  supply : nat;
}

type total_supply_param = {
  token_ids : token_id list;
  total_supply_view : (total_supply_response list) contract;
}

type token_descriptor = {
  symbol : string;
  name : string;
  decimals : nat;
  extras : (string, string) map;
}

type token_descriptor_response = {
  token_id : token_id;
  descriptor : token_descriptor;
}

type token_descriptor_param = {
  token_ids : token_id list;
  token_descriptor_view : (token_descriptor_response list) contract;
}

type fa2_entry_points =
  | Transfer of transfer_param
  | Balance_of of balance_of_param
  | Total_supply of total_supply_param
  | Token_descriptor of token_descriptor_param
  | Get_permissions_policy of ((permission_policy_config list) contract)

(** Different permission policy interfaces *)

(**
  Operator permission policy.
  Operator is a Tezos address which initiates token transfer operation.
  Owner is a Tezos address which can hold tokens. Owner can transfer its own tokens.
  Operator, other than the owner, MUST be approved to manage all tokens held by
  the owner to make a transfer from the owner account.

  The owner does not need to be approved to transfer its own tokens. 
 *)

type operator_param = {
  owner : address;
  operator : address; 
}

type is_operator_response = {
  operator : operator_param;
  is_operator : bool;
}

type is_operator_param = {
  operators : operator_param list;
  view : (is_operator_response list) contract;
}

type fa2_operators_config_entry_points =
  | Add_operators of operator_param list
  | Remove_operators of operator_param list
  | Is_operator of is_operator_param

(** 
  Receiver whitelist permission policy.
  Only addresses which are whitelisted can receive tokens. If one or more `to_`
  addresses in FA2 transfer batch are not whitelisted the whole transfer operation
  MUST fail.
*)

type is_whitelisted_response = {
  owner : address;
  is_whitelisted : bool;
}

type is_whitelisted_param = {
  owners : address list;
  whitelist_view : ((is_whitelisted_response list) contract);
}

type fa2_whitelist_config_entry_points = 
  | Add_to_white_list of address list
  | Remove_from_white_list of address list
  | Is_whitelisted of is_whitelisted_param
