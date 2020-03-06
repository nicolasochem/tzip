(**
Implementation of the permission transfer hook, which behavior is driven
by a particular settings of `permission_policy`.
*)

#include "fa2_behaviors.mligo"

type storage = {
  fa2_registry : fa2_registry;
  descriptor : permissions_descriptor;
}

type  entry_points =
  | Tokens_transferred_hook of transfer_descriptor_param
  | Register_with_fa2 of fa2_with_hook_entry_points contract

 let main (param, s : entry_points * storage) 
    : (operation list) * storage =
  match param with
  | Tokens_transferred_hook p ->
    let u = validate_hook_call (p.fa2, s.fa2_registry) in
    let ops = standard_transfer_hook (p, s.descriptor) in
    ops, s

  | Register_with_fa2 fa2 ->
    let op , new_registry = register_with_fa2 (fa2, s.descriptor, s.fa2_registry) in
    let new_s = { s with fa2_registry = new_registry; } in
    [op], new_s



(** example policies *)

(* the policy which allows only token owners to transfer their own tokens. *)
let own_policy : permissions_descriptor = {
  self = Self_transfer_permitted;
  operator = Operator_transfer_denied;
  sender = Owner_no_op;
  receiver = Owner_no_op;
  custom = (None : custom_permission_policy option);
}

(* non-transferable token (neither token owner, nor operators can transfer tokens. *)
  let own_policy : permissions_descriptor = {
  self = Self_transfer_denied;
  operator = Operator_transfer_denied;
  sender = Owner_no_op;
  receiver = Owner_no_op;
  custom = (None : custom_permission_policy option);
}
