type sub_token_id =
  | Single of unit
  | Mac of nat


type transfer = {
  token_id : sub_token_id;
  amount : nat;
}
type transfer_param = {
  from_ : address;
  to_ : address;
  batch : transfer list;
  data : bytes;
}

type balance_request = {
  owner : address; 
  token_id : sub_token_id;  
}

type balance_of_param = {
  balance_requests : balance_request list;
  balance_view : ((balance_request * nat) list) contract;
}

type total_supply_param = {
  total_supply_requests : sub_token_id list;
  total_supply_view : ((sub_token_id * nat) list) contract;
}

type token_descriptor = {
  url : string;
}

type token_descriptor_param = {
  token_ids : sub_token_id list;
  token_descriptor_view : ((sub_token_id * token_descriptor) list) contract
}

type hook_param = {
  from_ : address option;
  to_ : address option;
  batch : transfer list;
  data : bytes;
  operator : address;
}

type set_hook_param = hook_param contract


type fa2_entry_points =
  | Transfer of transfer_param
  | Balance_of of balance_of_param
  | Total_supply of total_supply_param
  | Token_descriptor of token_descriptor_param
  | Set_sender_hook of set_hook_param
  | Remove_sender_hook of address
  | Set_receiver_hook of set_hook_param
  | Remove_receiver_hook of address
  | Set_admin_hook of set_hook_param
  | Remove_admin_hook of unit
