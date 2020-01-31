(**
Implementation of the default permissioning hook.

Only token owner can initiate a transfer of tokens from their accounts
( `from_` MUST be equal to `SENDER`)
Any address can be a recipient of the token transfer
 *)

#include "../fa2_interface.mligo"

type  entry_points =
  | On_transfer_hook of hook_param
  | Register_with_fa2 of fa2_entry_points contract

let get_hook (hook_contract : address) (u : unit) : hook_param contract =
  let hook_entry : hook_param contract = 
    Operation.get_entrypoint "%on_transfer_hook" hook_contract in
  hook_entry

 let main (param, s : entry_points * unit) : (operation list) * unit =
  match param with
  | On_transfer_hook p ->
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
    let hook : unit -> hook_param contract = get_hook Current.self_address in
    let pp : set_hook_param = {
      hook = hook;
      config = No_config Current.self_address;
    } in
    let op = Operation.transaction (Set_transfer_hook pp) 0mutez fa2 in
    [op], s