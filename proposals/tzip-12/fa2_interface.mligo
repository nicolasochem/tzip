type token_id = nat
 
type transfer = {
  from_ : address;
  to_ : address;
  token_id : token_id;
  amount : nat;
}

type transfer_param = transfer list

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

(* permission policy and config definition *)

type policy_config_api = address

type custom_permission_policy = {
  tag : string;
  config_api: policy_config_api option;
}

type self_transfer_policy =
  | Self_transfer_permitted
  | Self_transfer_denied

type operator_transfer_policy =
  | Operator_transfer_permitted of policy_config_api
  | Operator_transfer_denied
  | Operator_transfer_custom of custom_permission_policy

type owner_transfer_policy =
  | Owner_no_op
  | Optional_owner_hook
  | Required_owner_hook
  | Owner_custom of custom_permission_policy

type permission_policy_descriptor = {
  self : self_transfer_policy;
  operator : operator_transfer_policy;
  receiver : owner_transfer_policy;
  sender : owner_transfer_policy;
  custom : custom_permission_policy option;
}

type fa2_entry_points =
  | Transfer of transfer_param
  | Balance_of of balance_of_param
  | Total_supply of total_supply_param
  | Token_descriptor of token_descriptor_param
  | Permissions_descriptor of permission_policy_descriptor contract

  type transfer_descriptor = {
  from_ : address option;
  to_ : address option;
  token_id : token_id;
  amount : nat;
}

type transfer_descriptor_param = {
  batch : transfer_descriptor list;
  operator : address;
}

type fa2_token_receiver =
  | Tokens_received of transfer_descriptor_param

type fa2_token_sender =
  | Tokens_sent of transfer_descriptor_param

(** Different permission policy config interfaces *)

(**
  Operator permission policy config API.
  Operator is a Tezos address which initiates token transfer operation.
  Owner is a Tezos address which can hold tokens.
  Operator, other than the owner, MUST be approved to manage all tokens held by
  the owner to make a transfer from the owner account.
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
