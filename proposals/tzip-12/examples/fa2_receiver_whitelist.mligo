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


(* registered FA2 contracts which can call this policy contract *)
type fa2_registry = address set

type whitelist = address set

type storage = {
  fa2_registry : fa2_registry;
  whitelist : whitelist;
}

let config_whitelist (param, s : fa2_whitelist_config_entry_points * whitelist)
    : (operation list) * whitelist =
  match param with
  | Add_to_white_list owners ->
    let new_s = List.fold (fun (w, cur : whitelist * address) -> Set.add cur w) owners s in
    ([] : operation list), new_s

  | Remove_from_white_list owners ->
    let new_s = List.fold (fun (w, cur : whitelist * address) -> Set.remove cur w) owners s in
    ([] : operation list), new_s

  | Is_whitelisted p ->
    let responses : is_whitelisted_response list =
      List.map (fun (owner : address) -> 
        { 
          owner = owner; 
          is_whitelisted = Set.mem owner s; 
        })
      p.owners in
    let op = Operation.transaction responses 0mutez p.whitelist_view in
    [op], s

let main (param, s : entry_points * storage) : (operation list) * storage =
  match param with
  | Whitelist p -> 
    let ops, new_wl = config_whitelist (p, s.whitelist) in
    let new_s = { s with whitelist = new_wl; } in
    ops, new_s

  | Tokens_transferred_hook p ->
    if Set.mem Current.sender s.fa2_registry
    then
      let u = List.iter (fun (tx : hook_transfer) ->
        let allowed = match tx.to_ with
        | None -> true
        | Some to_ -> Set.mem to_ s.whitelist
        in
        if allowed 
        then unit
        else failwith "receiver is not whitelisted"
      ) p.batch in
      ([] : operation list),  s
    else
      (failwith "unknown FA2 caller" : (operation list) * storage)

  | Register_with_fa2 fa2 ->
    let c : fa2_whitelist_config_entry_points contract = 
      Operation.get_entrypoint "%whitelist" Current.self_address in
    let config_address = Current.address c in
    let op = create_register_hook_op fa2 [Whitelist_config config_address] in

    let fa2_address = Current.address fa2 in
    let new_fa2s = Set.add fa2_address s.fa2_registry in
    let new_s = { s with fa2_registry = new_fa2s; } in

    [op], new_s
