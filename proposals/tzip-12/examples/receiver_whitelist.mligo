(**
Example of receiver whitelist implementation using admin hook of FA2

 *)

#include "../fa2_interface.mligo"


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
    let u = List.iter (fun (tx : transfer) ->
      if Set.mem tx.to_ s
      then unit
      else failwith "receiver is not whitelisted"
    ) p.batch in
    ([] : operation list),  s

  | Register_with_fa2 fa2 ->
    let hook : set_hook_param = 
      Operation.get_entrypoint "%on_admin_hook" Current.self_address in
    let pp  = Set_admin_hook (Some hook) in
    let op = Operation.transaction pp 0mutez fa2 in
    [op], s
