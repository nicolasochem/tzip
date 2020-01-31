(**
This is a sample implementation of the FA2 transfer hook which supports receiver
whitelist.

Only addresses which are whitelisted can receive tokens. If one or more `to_`
addresses in FA2 transfer batch are not whitelisted the whole transfer operation
MUST fail.

 *)

#include "../fa2_interface.mligo"


 type entry_points =
  | Add_receiver of address
  | Remove_receiver of address
  | On_admin_hook of hook_param
  | Register_with_fa2 of fa2_entry_points contract


type whitelist = address set

let get_hook (hook_contract : address) (u : unit) : hook_param contract =
  let hook_entry : hook_param contract = 
    Operation.get_entrypoint "%on_transfer_hook" hook_contract in
  hook_entry

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
    let hook : set_hook_param = get_hook Current.self_address in
    let pp = Set_transfer_hook  hook in
    let op = Operation.transaction pp 0mutez fa2 in
    [op], s
