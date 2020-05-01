#include "fa2_hook_lib.mligo"


(** generic transfer hook implementation. Behavior is driven by `permissions_descriptor` *)

type get_owner = transfer_descriptor -> address option
type to_hook = address -> ((transfer_descriptor_param contract) option * string)

let get_owners (batch, get_owner : (transfer_descriptor list) * get_owner) : address set =
  List.fold 
    (fun (acc, tx : (address set) * transfer_descriptor) ->
      match get_owner tx with
      | None -> acc
      | Some a -> Set.add a acc)
    batch
    (Set.empty : address set)

let validate_owner_hook (p, get_owner, to_hook, is_required :
    transfer_descriptor_param * get_owner * to_hook * bool)
    : operation list =
    let owners = get_owners (p.batch, get_owner) in
    Set.fold 
      (fun (ops, owner : (operation list) * address) ->
        let hook, error = to_hook owner in
        match hook with
        | Some h ->
          let op = Operation.transaction p 0mutez h in
          op :: ops
        | None ->
          if is_required
          then (failwith error : operation list)
          else ops)
      owners ([] : operation list)

let validate_owner(p, policy, get_owner, to_hook : 
    transfer_descriptor_param * owner_transfer_policy * get_owner * to_hook)
    : operation list =
  match policy with
  | Owner_no_op -> ([] : operation list)
  | Optional_owner_hook -> validate_owner_hook (p, get_owner, to_hook, false)
  | Required_owner_hook -> validate_owner_hook (p, get_owner, to_hook, true)

let to_receiver_hook : to_hook = fun (a : address) ->
    let c : (transfer_descriptor_param contract) option = 
    Operation.get_entrypoint_opt "%tokens_received" a in
    c, "RECEIVER_HOOK_UNDEFINED" 

let validate_receivers (p, policy : transfer_descriptor_param * owner_transfer_policy)
    : operation list =
  let get_receiver : get_owner = fun (tx : transfer_descriptor) -> tx.to_ in
  validate_owner (p, policy, get_receiver, to_receiver_hook)

let to_sender_hook : to_hook = fun (a : address) ->
    let c : (transfer_descriptor_param contract) option = 
    Operation.get_entrypoint_opt "%tokens_sent" a in
    c, "SENDER_HOOK_UNDEFINED" 

let validate_senders (p, policy : transfer_descriptor_param * owner_transfer_policy)
    : operation list =
  let get_sender : get_owner = fun (tx : transfer_descriptor) -> tx.from_ in
  validate_owner (p, policy, get_sender, to_sender_hook)

let standard_transfer_hook (p, descriptor : transfer_descriptor_param * permissions_descriptor)
    : operation list =
  let sender_ops = validate_senders (p, descriptor.sender) in
  let receiver_ops = validate_receivers (p, descriptor.receiver) in
  (* merge two lists *)
  List.fold (fun (l, o : (operation list) * operation) -> o :: l) receiver_ops sender_ops
