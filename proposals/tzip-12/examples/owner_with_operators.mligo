(**
  This is a sample token owner which supports operators
 *)

#include "../fa2_interface.mligo"

type operator_param = {
  owner : address;
  operator : address;
}

 type  entry_points =
  | Add_operator of operator_param
  | Remove_operator of operator_param
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
  | Add_operator p ->
    let ops = match Big_map.find_opt p.owner s with
    | Some os -> os
    | None -> (Set.empty : address set)
    in
    let new_ops = Set.add p.operator ops in
    let new_s = Big_map.update p.owner (Some new_ops) s in
    ([] : operation list),  new_s

  | Remove_operator p ->
    let ops = match Big_map.find_opt p.owner s with
    | Some os -> os
    | None -> (Set.empty : address set)
    in
    let new_ops = Set.remove p.operator ops in
    let new_s = Big_map.update p.owner (Some new_ops) s in
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
    let hook : set_hook_param = 
      Operation.get_entrypoint "%on_transfer_hook" Current.self_address in
    let pp = Set_sender_hook (Some hook) in
    let op = Operation.transaction pp 0mutez fa2 in
    [op], s
