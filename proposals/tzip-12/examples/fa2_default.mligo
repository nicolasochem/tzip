(**
Implementation of the default permissioning hook.

Only token owner can initiate a transfer of tokens from their accounts
( `from_` MUST be equal to `SENDER`)
Any address can be a recipient of the token transfer
 *)

#include "hook_lib.mligo"

(* registered FA2 contracts which can call this policy contract *)
type fa2_registry = address set

let validate_operator (p : hook_param) : unit =
  List.iter ( fun (tx : hook_transfer) ->
        match tx.from_ with
        | None -> unit
        | Some from_ -> 
          if from_ = p.operator
          then unit
          else failwith "cannot transfer tokens on behalf of other owner"
      ) p.batch

type  entry_points =
  | Tokens_transferred_hook of hook_param
  | Register_with_fa2 of fa2_with_hook_entry_points contract

 let main (param, s : entry_points * fa2_registry) 
    : (operation list) * fa2_registry =
  match param with
  | Tokens_transferred_hook p ->
    if Set.mem Current.sender s
    then
      let u = validate_operator p in
      ([] : operation list),  s
    else
      (failwith "unknown FA2 caller" : (operation list) * fa2_registry)

  | Register_with_fa2 fa2 ->
    let op = create_register_hook_op fa2 ([] : permission_policy_config list) in
    let fa2_address = Current.address fa2 in
    let new_s = Set.add fa2_address s in
    [op], new_s