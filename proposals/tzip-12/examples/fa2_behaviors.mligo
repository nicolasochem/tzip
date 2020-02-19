#include "fa2_hook_lib.mligo"

type operators = (address, (address set)) big_map

type operator_policy =
  | Operator_permitted of operators
  | Operator_denied

type permission_policy = {
  self: self_transfer_policy;
  operator : operator_policy;
  sender : owner_transfer_policy;
  receiver : owner_transfer_policy;
}


(** generic transfer hook implementation. Behavior is driven by `permission_policy` *)

let validate_operators (p, policy
    : transfer_descriptor_param * permission_policy) : unit =

  let operators = match policy.operator with
  | Operator_permitted ops -> ops
  | Operator_denied -> (Big_map.empty : operators)
  in
  let can_self_transfer : bool = match policy.self with
  | Self_transfer_permitted -> true
  | Self_transfer_denied -> false
  in

  let can_transfer_from = fun (from_ : address) ->
     if (can_self_transfer && p.operator = from_)
     then true
     else
      let from_ops = Big_map.find_opt from_ operators in
      match from_ops with
      |None -> false
      |Some ops -> Set.mem from_ ops
  in
  List.fold
    (fun (res, tx : bool * transfer_descriptor) ->
      match tx.from_ with
      | None -> res
      | Some addr -> can_transfer_from addr)
    p.batch
    true 

type get_owner = transfer_descriptor -> address option
type to_hook = address -> (transfer_descriptor_param contract) option

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
        let hook = to_hook owner in
        match hook with
        | Some h ->
          let op = Operation.transaction p 0mutez h in
          op :: ops
        | None ->
          if is_required
          then (failwith "token owner does not implement hook interface" : operation list)
          else ops)
      owners ([] : operation list)

let validate_owner(p, policy, get_owner, to_hook : 
    transfer_descriptor_param * owner_transfer_policy * get_owner * to_hook)
    : operation list =
  match policy with
  | Owner_no_op -> ([] : operation list)
  | Optional_owner_hook -> validate_owner_hook (p, get_owner, to_hook, false)
  | Required_owner_hook -> validate_owner_hook (p, get_owner, to_hook, true)
  | Owner_custom c -> (failwith "custom policy not supported" : operation list)


let validate_receivers (p, policy : transfer_descriptor_param * permission_policy)
    : operation list =
  let get_receiver : get_owner = fun (tx : transfer_descriptor) -> tx.to_ in
  let to_receiver_hook : to_hook = fun (a : address) ->
    let c : (transfer_descriptor_param contract) option = 
    Operation.get_entrypoint_opt "%tokens_received" a in
    c 
  in
  validate_owner (p, policy.receiver, get_receiver, to_receiver_hook)

let validate_senders (p, policy : transfer_descriptor_param * permission_policy)
    : operation list =
  let get_sender : get_owner = fun (tx : transfer_descriptor) -> tx.from_ in
  let to_sender_hook : to_hook = fun (a : address) ->
    let c : (transfer_descriptor_param contract) option = 
    Operation.get_entrypoint_opt "%tokens_sent" a in
    c 
  in
  validate_owner (p, policy.sender, get_sender, to_sender_hook)

let standard_transfer_hook (p, policy : transfer_descriptor_param * permission_policy)
    : operation list =
  let u = validate_operators (p, policy) in
  let sender_ops = validate_senders (p, policy) in
  let receiver_ops = validate_receivers (p, policy) in
  (* merge two lists *)
  List.fold (fun (l, o : (operation list) * operation) -> o :: l) receiver_ops sender_ops

(** Configuration API helpers *)

let asset_operator_config_by_owner_impl (ops : operator_param list) : unit =
  let s = Current.sender in
  List.iter 
    (fun (o : operator_param) -> 
      if o.owner = s 
      then unit 
      else failwith ("operators change not by owner"))
    ops
    

let add_operators (ops, operators
    : (operator_param list) * operators) : operators =
  List.fold 
    (fun (os, o : operators * operator_param) ->
      let owner_ops = 
        match Big_map.find_opt o.owner os with
        | Some o -> o
        | None -> (Set.empty : address set)
      in
      let new_owner_ops = Set.add o.operator owner_ops in
      Big_map.update o.owner (Some new_owner_ops) os)
    ops operators

let remove_operators (ops, operators
    : (operator_param list) * operators) : operators =
  List.fold 
    (fun (os, o : operators * operator_param) ->
      let owner_ops = 
        match Big_map.find_opt o.owner os with
        | Some o -> o
        | None -> (Set.empty : address set)
      in
      let new_owner_ops = Set.remove o.operator owner_ops in
      let update_ops =
        if (Set.size new_owner_ops) = 0n
        then (None : (address set) option)
        else Some new_owner_ops
      in
      Big_map.update o.owner update_ops os)
    ops operators

let is_operator (p, ops : is_operator_param * operators) : operation =
  let responses : is_operator_response list = List.map 
    (fun (r : operator_param) ->
      let os = Big_map.find_opt r.owner ops in
      let is_op = match os with
      | None -> false
      | Some o -> Set.mem r.operator o
      in
      { operator = r; is_operator = is_op })
    p.operators in
    Operation.transaction responses 0mutez p.view



let configure_operators_impl (p, operators
    : fa2_operators_config_entry_points * operators) : (operation list) * operators =
  match p with
  | Add_operators ops ->
    let new_operators = add_operators (ops, operators) in
    ([] : operation list), new_operators

  | Remove_operators ops ->
    let new_operators = remove_operators (ops, operators) in
    ([] : operation list), new_operators

  | Is_operator p ->
    let op = is_operator (p, operators) in
    [op], operators


let asset_operator_config_by_owner (p : fa2_operators_config_entry_points) : unit =
  match p with
  | Add_operators ops -> asset_operator_config_by_owner_impl ops
  | Remove_operators ops -> asset_operator_config_by_owner_impl ops
  | Is_operator p -> unit

let configure_operators (p, policy
    : fa2_operators_config_entry_points * permission_policy)
    : (operation list) * permission_policy =
  match policy.operator with
  | Operator_denied -> 
    (failwith "operators are not supported" : (operation list) * permission_policy)
  | Operator_permitted ops ->
    let ops, new_operators = configure_operators_impl (p, ops) in
    let new_policy = { policy with operator = Operator_permitted new_operators; } in
    ops, new_policy

let policy_to_descriptor (p : permission_policy) : permission_policy_descriptor =
  let operator = match p.operator with
  | Operator_permitted os -> Operator_transfer_permitted Current.self_address
  | Operator_denied -> Operator_transfer_denied
  in 
  {
    self = p.self;
    operator = operator;
    receiver = p.receiver;
    sender = p.sender;
    custom = (None : custom_permission_policy option);
  }
