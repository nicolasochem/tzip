#include "../fa2_interface.mligo"

let get_hook (hook_contract : address) (u : unit) : hook_param contract =
  let hook_entry : hook_param contract = 
    Operation.get_entrypoint "%on_transfer_hook" hook_contract in
  hook_entry


let create_register_hook_op 
    (fa2 : fa2_entry_points contract) (config : permission_policy_config) : operation =
  let hook : unit -> hook_param contract = get_hook Current.self_address in
  let pp : set_hook_param = {
    hook = hook;
    config = config;
  } in
  Operation.transaction (Set_transfer_hook pp) 0mutez fa2
