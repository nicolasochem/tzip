(**
  This is a sample implementation of the FA2 transfer hook which supports transfer
  operators.
  Operator is a Tezos address which initiates token transfer operation.
  Owner is a Tezos address which can hold tokens. Owner can transfer its own tokens.
  Operator, other than the owner, MUST be approved to manage all tokens held by
  the owner to make a transfer from the owner account.
  Only token owner can add or remove its operators. The owner does not need to be
  approved to transfer its own tokens.
 *)

#include "hook_lib.mligo"

(* registered FA2 contracts which can call this policy contract *)
type fa2_registry = address set

(* owner -> operator set*)
type operators = (address, (address set)) big_map

type storage = {
  fa2_registry : fa2_registry;
  operators : operators;
}

 type  entry_points =
  | Operators of fa2_operators_config_entry_points
  | Tokens_transferred_hook of hook_param
  | Register_with_fa2 of fa2_with_hook_entry_points contract


let is_allowed (owner : address) (operator : address) (operators : operators) : bool =
  if owner = operator
  then true
  else
    let ops = 
      match Big_map.find_opt owner operators with
      | Some ops -> ops
      | None -> (Set.empty : address set)
    in
    if Set.mem operator ops
    then true
    else false

let validate_owner_and_get_operators (owner : address) (ops : operator_param list)
    (s : operators) : address set =
  let u = List.iter (fun (op : operator_param) ->
    if op.owner = owner
    then unit
    else failwith "only token owner can modify its operators") ops in
  match Big_map.find_opt owner s with
  | Some os -> os
  | None -> (Set.empty : address set)

let config_operators (param : fa2_operators_config_entry_points) (s : operators)
    : (operation list) * operators =
  match param with
  | Add_operators p ->
    let owner = Current.sender in
    let ops = validate_owner_and_get_operators owner p s in
    let new_ops = List.fold 
      (fun (so, cur : (address set) * operator_param) 
        -> Set.add cur.operator so)
      p ops  in
    let new_s = Big_map.update owner (Some new_ops) s in
    ([] : operation list), new_s

  | Remove_operators p ->
    let owner = Current.sender in
    let ops = validate_owner_and_get_operators owner p s in
    let new_ops = List.fold 
      (fun (so, cur : (address set) * operator_param) 
        -> Set.remove cur.operator so)
      p ops  in
    let new_s = Big_map.update owner (Some new_ops) s in
    ([] : operation list), new_s

  | Is_operator p ->
    let r : is_operator_response list = List.map 
      (fun (op : operator_param) ->
        let is_op = match Big_map.find_opt op.owner s with
        | None -> false
        | Some ops -> Set.mem op.operator ops
        in 
        let resp : is_operator_response = { 
          operator = op;
          is_operator = is_op;
        } in
        resp
      )
      p.operators in
      let view_op = Operation.transaction r 0mutez p.view in
      [view_op], s
      (* ([] : operation list), s *)

let main (param, s : entry_points * storage) : (operation list) * storage =
  match param with  
  | Operators oc -> 
    let ops, new_operators = config_operators oc s.operators in
    let new_s = { s with operators = new_operators; } in
    ops, new_s
  
  | Tokens_transferred_hook p ->
    if Set.mem Current.sender s.fa2_registry
    then
      let u = List.iter (fun (tx : hook_transfer) ->
        let allowed = match tx.from_ with
        | None -> true
        | Some from_ -> is_allowed from_ p.operator s.operators
        in
        if allowed 
        then unit
        else failwith "operator is not allowed"
      ) p.batch in
      ([] : operation list),  s
    else
      (failwith "unknown FA2 caller" : (operation list) * storage)

  | Register_with_fa2 fa2 ->
    let c : fa2_operators_config_entry_points contract = 
      Operation.get_entrypoint "%operators" Current.self_address in
    let config_address = Current.address c in
    let op = create_register_hook_op fa2 [Operators_config config_address] in

    let fa2_address = Current.address fa2 in
    let new_fa2s = Set.add fa2_address s.fa2_registry in
    let new_s = { s with fa2_registry = new_fa2s; } in
    
    [op], new_s
