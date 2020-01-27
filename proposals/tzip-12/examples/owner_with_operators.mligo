(**
  This is a sample token owner which supports operators
 *)

#include "../fa2_interface.mligo"



 type  entry_points =
  | Add_operator of address
  | Remove_operator of address
  | On_send_hook of hook_param
  | Register_with_fa2 of fa2_entry_points contract


type operators = address set

let main (param : entry_points) (s : operators) : (operation list) * operators =
  match param with
  | Add_operator op -> 
    let new_s = Set.add op s in
    ([] : operation list),  new_s

  | Remove_operator op ->
    let new_s = Set.remove op s in
    ([] : operation list),  new_s

  | On_send_hook p ->
    if p.operator = Current.self_address or  Set.mem p.operator
    then ([] : operation list),  s
    else (failwith "operator is not allowed" : (operation list) * operators)

  | Register_with_fa2 fa2 ->
    let hook : set_hook_param = 
      Operation.get_entrypoint "%on_send_hook" Current.self_address in
    let pp = Some (Set_sender_hook hook)
    let op = Operation.transaction pp 0mutez fa2
