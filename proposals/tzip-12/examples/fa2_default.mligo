(**
Implementation of the permission transfer hook, which behavior is driven
by a particular settings of `permission_policy`.
*)

#include "fa2_behaviors.mligo"

type storage = {
  fa2_registry : fa2_registry;
  policy : permission_policy;
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
    let ops = standard_transfer_hook (p, s.policy) in
    ops, s

  | Register_with_fa2 fa2 ->
    let descriptor = policy_to_descriptor s.policy in
    let op , new_registry = register_with_fa2 (fa2, descriptor, s.fa2_registry) in
    let new_s = { s with fa2_registry = new_registry; } in
    [op], new_s

  | Config_operators cfg ->
    let u = match s.policy.self_ with
    (* assume if self transfers permitted only owner can config its own operators *)
    | Self_transfer_permitted -> asset_operator_config_by_owner cfg
    (* assume it is called by the admin *)
    | Self_transfer_denied -> unit
    in
    let ops, new_policy = configure_operators (cfg, s.policy) in
    let new_s = { s with policy = new_policy; } in
    ops, new_s



(** example policies *)

(* the policy which allows only token owners to transfer their own tokens. *)
(* let own_policy : permission_policy = {
  self = Self_transfer_permitted;
  operators = Operator_transfer_denied;
  sender = Owner_no_op;
  receiver = Owner_no_op;
}

(* non-transferable token (neither token owner, nor operators can transfer tokens. *)
  let own_policy : permission_policy = {
  self = Self_transfer_denied;
  operators = Operator_transfer_denied;
  sender = Owner_no_op;
  receiver = Owner_no_op;
} *)


let test (p : unit) = unit