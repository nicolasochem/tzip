#include "../fa2_hook.mligo"

let get_hook_entrypoint (hook_contract : address) (u : unit) 
    : transfer_descriptor_param contract =
  let hook_entry : transfer_descriptor_param contract = 
    Operation.get_entrypoint "%tokens_transferred_hook" hook_contract in
  hook_entry


let create_register_hook_op 
    (fa2, descriptor : (fa2_with_hook_entry_points contract) * permissions_descriptor) : operation =
  let hook_fn = get_hook_entrypoint Current.self_address in
  let pp : set_hook_param = {
    hook = hook_fn;
    permissions_descriptor = descriptor;
  } in
  Operation.transaction (Set_transfer_hook pp) 0mutez fa2


type fa2_registry = address set

let register_with_fa2 (fa2, descriptor, registry : 
    (fa2_with_hook_entry_points contract) * permissions_descriptor * fa2_registry) 
    : operation * fa2_registry =
  let op = create_register_hook_op (fa2, descriptor) in
  let fa2_address = Current.address fa2 in
  let new_registry = Set.add fa2_address registry in
  op, new_registry

let validate_hook_call (fa2, registry: address * fa2_registry) : unit =
  if Set.mem fa2 registry
  then unit
  else failwith "unknown FA2 contract called a transfer hook"