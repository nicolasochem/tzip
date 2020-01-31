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


 type  entry_points =
  | Add_operator of address
  | Remove_operator of address
  | On_transfer_hook of hook_param
  | Register_with_fa2 of fa2_entry_points contract


(* owner -> operator set*)
type operators = (address, (address set)) big_map

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

let main (param, s : entry_points * operators) : (operation list) * operators =
  match param with
  | Add_operator operator ->
    let owner = Current.sender in
    let ops = match Big_map.find_opt owner s with
    | Some os -> os
    | None -> (Set.empty : address set)
    in
    let new_ops = Set.add operator ops in
    let new_s = Big_map.update owner (Some new_ops) s in
    ([] : operation list),  new_s

  | Remove_operator operator ->
    let owner = Current.sender in
    let ops = match Big_map.find_opt owner s with
    | Some os -> os
    | None -> (Set.empty : address set)
    in
    let new_ops = Set.remove operator ops in
    let new_s = Big_map.update owner (Some new_ops) s in
    ([] : operation list),  new_s
  
  | On_transfer_hook p ->
    let u = List.iter (fun (tx : hook_transfer) ->
      let allowed = match tx.from_ with
      | None -> true
      | Some from_ -> is_allowed from_ p.operator s
      in
      if allowed 
      then unit
      else failwith "operator is not allowed"
    ) p.batch in
    ([] : operation list),  s

  | Register_with_fa2 fa2 ->
    let op = create_register_hook_op fa2 (Operator_config Current.self_address) in
    [op], s
