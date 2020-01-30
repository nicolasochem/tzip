# 1 "examples/receiver_whitelist.mligo"
# 1 "<built-in>"
# 1 "<command-line>"
# 1 "examples/receiver_whitelist.mligo"
(**
Example of receiver whitelist implementation using admin hook of FA2

 *)


# 1 "examples/../fa2_interface.mligo" 1
type token_id =
  | Single of unit
  | Mac of nat

type transfer = {
  from_ : address;
  to_ : address;
  token_id : token_id;
  amount : nat;
}
type transfer_param = {
  batch : transfer list;
  data : bytes option;
}

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
  total_supply_requests : token_id list;
  total_supply_view : (total_supply_response list) contract;
}

type token_descriptor = {
  symbol: string;
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
  token_descriptor_view : (token_descriptor_response list) contract
}
type hook_transfer = {
  from_ : address option; (* None for minting *)
  to_ : address option;   (* None for burning *)
  token_id : token_id;
  amount : nat;
}

type hook_param = {
  batch : hook_transfer list;
  data : bytes option;
  operator : address;
}

type set_hook_param = hook_param contract


type fa2_entry_points =
  | Transfer of transfer_param
  | Balance_of of balance_of_param
  | Total_supply of total_supply_param
  | Token_descriptor of token_descriptor_param
  | Set_sender_hook of set_hook_param option
  | Set_receiver_hook of set_hook_param option
  | Set_admin_hook of set_hook_param option
# 7 "examples/receiver_whitelist.mligo" 2


 type entry_points =
  | Add_receiver of address
  | Remove_receiver of address
  | On_admin_hook of hook_param
  | Register_with_fa2 of fa2_entry_points contract


type whitelist = address set

let main (param, s : entry_points * whitelist) : (operation list) * whitelist =
  match param with
  | Add_receiver op -> 
    let new_s = Set.add op s in
    ([] : operation list),  new_s

  | Remove_receiver op ->
    let new_s = Set.remove op s in
    ([] : operation list),  new_s

  | On_admin_hook p ->
    let u = List.iter (fun (tx : hook_transfer) ->
      let allowed = match tx.to_ with
      | None -> true
      | Some to_ -> Set.mem to_ s
      in
      if allowed 
      then unit
      else failwith "receiver is not whitelisted"
    ) p.batch in
    ([] : operation list),  s

  | Register_with_fa2 fa2 ->
    let hook : set_hook_param = 
      Operation.get_entrypoint "%on_transfer_hook" Current.self_address in
    let pp  = Set_admin_hook (Some hook) in
    let op = Operation.transaction pp 0mutez fa2 in
    [op], s
