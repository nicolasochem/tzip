(**
  This is a sample implementation of the FA2 transfer hook which supports transfer
  allowances for token spenders.
  Spender is a Tezos address which initiates token transfer operation.
  Owner is a Tezos address which can hold tokens. Owner can transfer its own tokens.
  Spender, other than the owner, MUST be approved to withdraw specific tokens held by
  the owner up to the allowance amount.
  Only token owner can set allowances for specific token types and spenders. 
  The owner does not need to be approved to transfer its own tokens.
 *)

#include "hook_lib.mligo"


type  entry_points =
  | Allowances of fa2_allowances_config_entry_points
  | Tokens_transferred_hook of hook_param
  | Register_with_fa2 of fa2_with_hook_entry_points contract

(**
This will not work with babylon/LIGO since `allowance_key` is a composite
non-comparable record which cannot be used as a key in the big_map.
 *)
type allowances = (allowance_id, nat) big_map

let get_current_allowance (id : allowance_id) (a : allowances) : nat =
  let a = Big_map.find_opt id a in
  match a with
  | Some a -> a
  | None -> 0n

let track_allowances (operator : address) (a_tx : allowances * hook_transfer) : allowances =
  let a , tx = a_tx in
  match tx.from_ with
  | None -> a
  | Some from_ ->
    if Current.self_address <> from_
    then a
    else
      let id : allowance_id = {
        owner = from_;
        token_id = tx.token_id;
        token_manager = Current.sender;
        spender = operator;
      } in 
      let allowance = get_current_allowance id a in
      let new_a = Michelson.is_nat (allowance - tx.amount) in
      let new_allowance = match new_a with
      | None -> (failwith "Insufficient allowance" : nat)
      | Some a -> a
      in
      let new_a = Big_map.update id (Some new_allowance) a in
      new_a

let validate_owner (allowances : set_allowance_param list) : unit = 
  let owner = Current.self_address in
  let u = List.iter (fun (a : set_allowance_param) ->
      if a.allowance_id.owner = owner
      then unit
      else failwith "only owner can change its allowances"
    ) allowances in
  unit

let config_allowances (param : fa2_allowances_config_entry_points) (s : allowances)
    : (operation list) * allowances =
  match param with
  | Set_allowances ps ->
    let u = validate_owner ps in
    let new_s = List.fold (fun (a, cur : allowances * set_allowance_param ) ->
        (* compare and swap *)
        let allowance = get_current_allowance cur.allowance_id s in
        if allowance <> cur.prev_allowance
        then (failwith "cannot update allowance" : allowances)
        else Big_map.update cur.allowance_id (Some cur.new_allowance) a
      ) ps s in
    ([] : operation list),  new_s

  | Get_allowances p ->
    let resp = List.map (fun (id : allowance_id) ->
        let allowance = get_current_allowance id s in
        let r : get_allowance_response = {
          allowance_id = id;
          allowance = allowance;
        } in
        r
      ) p.allowance_ids in
    let op = Operation.transaction resp 0mutez p.view in
    [op], s

let main (param, s : entry_points * allowances) : (operation list) * allowances =
  match param with

  | Allowances p -> config_allowances p s

  | Tokens_transferred_hook p ->
    let new_s = List.fold (track_allowances p.operator) p.batch s in
    ([] : operation list),  new_s

  | Register_with_fa2 fa2 ->
    let c : fa2_allowances_config_entry_points contract = 
      Operation.get_entrypoint "%allowances" Current.self_address in
    let config_address = Current.address c in
    let op = create_register_hook_op fa2 [Allowances_config config_address] in
    [op], s
