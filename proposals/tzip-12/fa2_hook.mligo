#include "fa2_interface.mligo"


type set_hook_param = {
  hook : address;
  config : permission_policy_config list;
}

type fa2_with_hook_entry_points =
  | Fa2 of fa2_entry_points
  | Set_transfer_hook of set_hook_param 