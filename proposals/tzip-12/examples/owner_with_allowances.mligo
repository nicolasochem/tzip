(**
  This is a sample token owner which supports token allowances
 *)

#include "../fa2_interface.mligo"

type global_token_id = {
  manager : address;
  token_id : token_id;
}

type allowance_key = {
  token_id : global_token_id;
  spender : address;
}

type allowance_response = {
  key: allowance_key;
  allowance : nat;
}

type change_allowance_param = {
  key : allowance_key;
  prev_allowance : nat;
  new_allowance : nat;
}

type view_allowance_param = {
  key : allowance_key;
  view : allowance_response contract;
}


type  entry_points =
  | Change_allowance of change_allowance_param
  | View_allowance of view_allowance_param
  | On_send_hook of hook_param
  | Register_with_fa2 of fa2_entry_points contract

(**
This will not work with babylon/LIGO since `allowance_key` is a composite
non-comparable record which cannot be used as a key in the big_map.
 *)
type allowances = (allowance_key, nat) big_map

let get_allowance_key (operator : address) (tx : hook_transfer) : allowance_key =
  let tid : global_token_id = {
    manager = sender;
    token_id = tx.token_id;
  } in
  {
    token_id = tid;
    spender = operator;
  }

let get_current_allowance (key : allowance_key) (a : allowances) : nat =
  let a = Big_map.find_opt key a in
  match a with
  | Some a -> a
  | None -> 0n

let track_allowances (operator : address) (a_tx : allowances * hook_transfer) : allowances =
  match a_tx.1.from_ with
  | None -> a_tx.0 
  | Some from_ ->
    if Current.self_address <> from_
    then a_tx.0 
    else
      let akey = get_allowance_key operator a_tx.1 in
      let allowance = get_current_allowance akey a_tx.0 in
      let new_a = Michelson.is_nat (allowance - a_tx.1.amount) in
      let new_allowance = match new_a with
      | None -> (failwith "Insufficient allowance" : nat)
      | Some a -> a
      in
      let new_a = Big_map.update akey (Some new_allowance) a_tx.0 in
      new_a

let main (param, s : entry_points * allowances) : (operation list) * allowances =
  match param with

  | Change_allowance p ->
    (* compare and swap *)
    let allowance = get_current_allowance p.key s in
    if allowance <> p.prev_allowance
    then (failwith "cannot update allowance" : (operation list) * allowances)
    else
      let new_s = Big_map.update p.key (Some p.new_allowance) s in
      ([] : operation list),  new_s

  | View_allowance p ->
    let allowance = get_current_allowance p.key s in
    let resp : allowance_response = {
      key = p.key;
      allowance = allowance;
    } in
    let op = Operation.transaction resp 0mutez p.view in
    [op], s

  | On_send_hook p ->
    if p.operator = Current.self_address
    then ([] : operation list),  s
    else
      let new_s = List.fold (track_allowances p.operator) p.batch s in
      ([] : operation list),  new_s

  | Register_with_fa2 fa2 ->
    let hook : set_hook_param = 
      Operation.get_entrypoint "%on_send_hook" Current.self_address in
    let pp = Set_sender_hook (Some hook) in
    let op = Operation.transaction pp 0mutez fa2 in
    [op], s

