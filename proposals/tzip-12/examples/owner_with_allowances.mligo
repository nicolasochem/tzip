(**
  This is a sample token owner which supports token allowances
 *)

#include "../fa2_interface.mligo"

type global_token_id = {
  manager : address;
  sub_token_id : token_id;
}

type allowance_key = {
  token_id : global_token_id;
  spender : address;
}

type allowance_response = {
  request: allowance_key;
  allowance : nat;
}

type allowances = (allowance_key, nat) big_map

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


let get_allowance_key (tx : transfer) : allowance_key =
  let tid : global_token_id = {
    manager = sender;
    token_id = transfer.token_id;
  } in
  {
    token_id = tid;
    spender = tx.operator;
  }

let track_allowances (a : allowances) (tx: transfer) : allowances =
  if Current.self_address <> tx.from_
  then a 
  else
    let akey = get_allowance_key tx in
    let a = Big_map.find_opt akey a in
    let allowance = match a with
    | Some a -> a
    | None -> 0n
    in
    let new_a = Michelson.is_nat (allowance - tx.amount) in
    let new_allowance = match new_a with
    | None -> (failwith "Insufficient allowance" : allowances)
    | Some a -> a
    in
    Big_map.update akey Some(new_allowance) a



let main (param : entry_points) (s : allowances) : (operation list) * allowances =
  match param with

  | Change_allowance p ->
    let a = Big_map.find_opt p.key s in
    let allowance = match a with
    | Some a -> a
    | None -> 0n
    in
    if allowance <> p.prev_allowance
    then (failwith "cannot update allowance" : (operation list) * allowances)
    else
      let new_s = Big_map.update akey Some(p.new-new_allowance) s in
      ([] : operation list),  new_s

  | View_allowance p ->
    let a = Big_map.find_opt p.request s in
    let allowance = match a with
    | Some a -> a
    | None -> 0n
    in
    let resp : allowance_response = {
      request = p.request;
      allowance = allowance;
    } in
    let op = Operation.transaction resp 0mutez p.view in
    [op], s

  | On_send_hook p ->
    if p.operator = Current.self_address
    then ([] : operation list),  s
    else 
      let new_s = List.fold track_allowances p.batch s in
      ([] : operation list),  new_s

  | Register_with_fa2 fa2 ->
    let hook : set_hook_param = 
      Operation.get_entrypoint "%on_send_hook" Current.self_address in
    let pp = Some (Set_sender_hook hook)
    let op = Operation.transaction pp 0mutez fa2
