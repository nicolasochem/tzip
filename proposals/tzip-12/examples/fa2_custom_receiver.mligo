(**
Implementation of the permission transfer hook, with custom behavior.
It uses a combination of a receiver while list and `fa2_token_receiver` interface.
Transfer is permitted if a receiver address is in the receiver white list OR implements
`fa2_token_receiver` interface. If a receiver address implements `fa2_token_receiver`
interface, its `tokens_received` entry point must be called.
*)

#include "fa2_behaviors.mligo"


type storage = {
  fa2_registry : fa2_registry;
  receiver_whitelist : address set;
} 

let custom_validate_receivers (p, wl : transfer_descriptor_param * (address set))
    : operation list =
  let get_receiver : get_owner = fun (tx : transfer_descriptor) -> tx.to_ in
  let receivers = get_owners (p.batch, get_receiver) in

  Set.fold 
    (fun (ops, r : (operation list) * address) ->
      let hook = to_sender_hook r in
      match hook with
      | Some h ->
        let op = Operation.transaction p 0mutez h in
        op :: ops
      | None ->
        if Set.mem r wl
        then ops
        else (failwith "receiver not permitted" : operation list) 
    )
    receivers ([] : operation list)

let custom_transfer_hook (p, s : transfer_descriptor_param * storage) : operation list =
  custom_validate_receivers (p, s.receiver_whitelist)


let get_policy_descriptor (u : unit) : permission_policy_descriptor =
  {
    self = Self_transfer_permitted;
    operator = Operator_transfer_permitted;
    sender = Owner_no_op;
    receiver = Owner_custom { 
      tag = "receiver_hook_and_whitelist"; 
      config_api = (Some Current.self_address);
    };
    custom = (None : custom_permission_policy option);
  }

type config_whitelist = 
  | Add_receiver_to_whitelist of address set
  | Remove_receiver_from_whitelist of address set

let configure_receiver_whitelist (cfg, wl : config_whitelist * (address set))
    : address set =
  match cfg with
  | Add_receiver_to_whitelist rs ->
    Set.fold 
      (fun (l, a : (address set) * address) -> Set.add a l)
      rs wl
  | Remove_receiver_from_whitelist rs ->
     Set.fold 
      (fun (l, a : (address set) * address) -> Set.remove a l)
      rs wl

type  entry_points =
  | Tokens_transferred_hook of transfer_descriptor_param
  | Register_with_fa2 of fa2_with_hook_entry_points contract
  | Config_receiver_whitelist of config_whitelist

 let main (param, s : entry_points * storage) 
    : (operation list) * storage =
  match param with
  | Tokens_transferred_hook p ->
    let u = validate_hook_call (p.fa2, s.fa2_registry) in
    let ops = custom_transfer_hook (p, s) in
    ops, s

  | Register_with_fa2 fa2 ->
    let descriptor = get_policy_descriptor unit in
    let op , new_registry = register_with_fa2 (fa2, descriptor, s.fa2_registry) in
    let new_s = { s with fa2_registry = new_registry; } in
    [op], new_s

  | Config_receiver_whitelist cfg ->
    let new_wl = configure_receiver_whitelist (cfg, s.receiver_whitelist) in
    let new_s = { s with receiver_whitelist = new_wl; } in
    ([] : operation list), new_s
