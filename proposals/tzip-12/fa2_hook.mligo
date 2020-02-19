#include "fa2_interface.mligo"


type set_hook_param = {
  hook : address;
  permissions_descriptor : permission_policy_descriptor;
}

type fa2_with_hook_entry_points =
  | Fa2 of fa2_entry_points
  | Set_transfer_hook of set_hook_param


