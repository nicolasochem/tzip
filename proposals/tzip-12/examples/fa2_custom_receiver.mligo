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
  operators : operators;
  receiver_whitelist : address set;
}

let custom_validate_operators (p, operators : transfer_descriptor_param * operators) : unit =
  let can_transfer_from = fun (from_ : address) ->
     if (from_ = p.operator)
     then true
     else
      let from_ops = Big_map.find_opt from_ operators in
      match from_ops with
      |None -> false
      |Some ops -> Set.mem p.operator ops
  in
  List.fold
    (fun (res, tx : bool * transfer_descriptor) ->
      match tx.from_ with
      | None -> res
      | Some addr -> 
        if (can_transfer_from addr) then res else false)
    p.batch
    true 

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
  let u = custom_validate_operators (p, s.operators) in
  custom_validate_receivers (p, s.receiver_whitelist)


let get_policy_descriptor (u : unit) : permission_policy_descriptor =
  let sa = Current.self_address in
  {
    self = Self_transfer_permitted;
    operator = Operator_transfer_permitted sa;
    sender = Owner_no_op;
    receiver = Owner_custom { 
      tag = "receiver_hook_and_whitelist"; 
      config_api = Some sa;
    };
    custom = (None : custom_permission_policy option);
  }

type  entry_points =
  | Tokens_transferred_hook of transfer_descriptor_param
  | Register_with_fa2 of fa2_with_hook_entry_points contract
  | Config_operators of fa2_operators_config_entry_points

 let main (param, s : entry_points * storage) 
    : (operation list) * storage =
  match param with
  | Tokens_transferred_hook p ->
    let u = validate_hook_call (Current.sender, s.fa2_registry) in
    let ops = custom_transfer_hook (p, s) in
    ops, s

  | Register_with_fa2 fa2 ->
    let descriptor = get_policy_descriptor unit in
    let op , new_registry = register_with_fa2 (fa2, descriptor, s.fa2_registry) in
    let new_s = { s with fa2_registry = new_registry; } in
    [op], new_s

  | Config_operators cfg ->
    let u = asset_operator_config_by_owner cfg in
    let ops, new_operators = configure_operators_impl (cfg, s.operators) in
    let new_s = { s with operators = new_operators; } in
    ops, new_s
