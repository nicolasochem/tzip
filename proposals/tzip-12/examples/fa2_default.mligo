(**
Implementation of the default permissioning hook.

Only token owner can initiate a transfer of tokens from their accounts
( `from_` MUST be equal to `SENDER`)
Any address can be a recipient of the token transfer
 *)

#include "hook_lib.mligo"

type  entry_points =
  | Tokens_transferred_hook of hook_param
  | Register_with_fa2 of fa2_entry_points contract

 let main (param, s : entry_points * unit) : (operation list) * unit =
  match param with
  | Tokens_transferred_hook p ->
    let u = List.iter ( fun (tx : hook_transfer) ->
      match tx.from_ with
      | None -> unit
      | Some from_ -> 
        if from_ = p.operator
        then unit
        else failwith "cannot transfer tokens on behalf of other owner"
    ) p.batch in
    ([] : operation list),  unit

  | Register_with_fa2 fa2 ->
    let op = create_register_hook_op fa2 ([] : permission_policy_config list) in
    [op], s