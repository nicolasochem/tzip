type token_id = nat

type transfer = {
  from_ : address;
  to_ : address;
  token_id : token_id;
  amount : nat;
}

type balance_request = {
  owner : address;
  token_id : token_id;  
}

type balance_response = {
  request : balance_request;
  balance : nat;
}

type balance_param = {
  requests : balance_request list;
  callback : (balance_response list) contract;
}

type total_supply_response = {
  token_id : token_id;
  total_supply : nat;
}

type total_supply_param = {
  token_ids : token_id list;
  callback : (total_supply_response list) contract;
}

type token_metadata = {
  symbol : string;
  name : string;
  decimals : nat;
  extras : (string, string) map;
}

type token_metadata_response = {
  token_id : token_id;
  token_metadata : token_metadata;
}

type token_metadata_param = {
  token_ids : token_id list;
  callback : (token_metadata_response list) contract;
}

type operator_tokens =
  | All_tokens
  | Some_tokens of token_id set

type operator_param = {
  owner : address;
  operator : address;
  tokens : operator_tokens;
}

type update_operator =
  | Add_operator of operator_param
  | Remove_operator of operator_param

type is_operator_response = {
  operator : operator_param;
  is_operator : bool;
}

type is_operator_param = {
  operator : operator_param;
  callback : (is_operator_response) contract;
}

(* permission policy definition *)

type policy_config_api = address

type custom_permission_policy = {
  tag : string;
  config_api: policy_config_api option;
}

type self_transfer_policy =
  | Self_transfer_permitted
  | Self_transfer_denied

type operator_transfer_policy =
  | Operator_transfer_permitted
  | Operator_transfer_denied
  | Operator_custom of custom_permission_policy

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
  | Transfer of transfer list
  | Balance of balance_param
  | Total_supply of total_supply_param
  | Token_metadata of token_metadata_param
  | Permissions_descriptor of permission_policy_descriptor contract
  | Update_operators of update_operator list
  | Is_operator of is_operator_param

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
