(**
This is a sample implementation of the FA2 transfer hook which supports receiver
whitelist.

Only addresses which are whitelisted can receive tokens. If one or more `to_`
addresses in FA2 transfer batch are not whitelisted the whole transfer operation
MUST fail.

 *)

#include "hook_lib.mligo"


 type entry_points =
  | Whitelist of fa2_whitelist_config_entry_points
  | Tokens_transferred_hook of hook_param
  | Register_with_fa2 of fa2_with_hook_entry_points contract


type whitelist = address set

let config_whitelist (param : fa2_whitelist_config_entry_points) (s : whitelist)
    : (operation list) * whitelist =
  match param with
  | Add_to_white_list owners ->
    let new_s = List.fold (fun (w, cur : whitelist * address) -> Set.add cur w) owners s in
    ([] : operation list), new_s

  | Remove_from_white_list owners ->
    let new_s = List.fold (fun (w, cur : whitelist * address) -> Set.remove cur w) owners s in
    ([] : operation list), new_s

let main (param, s : entry_points * whitelist) : (operation list) * whitelist =
  match param with
  | Whitelist p -> config_whitelist p s

  | Tokens_transferred_hook p ->
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
    let c : fa2_whitelist_config_entry_points contract = 
      Operation.get_entrypoint "%whitelist" Current.self_address in
    let config_address = Current.address c in
    let op = create_register_hook_op fa2 [Whitelist_config config_address] in
    [op], s
