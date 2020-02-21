(**
Implementation of the permission transfer hook, which behavior is driven
by a particular settings of `permission_policy`.
It supports granular operators permissioning per token type.
*)

#include "fa2_behaviors.mligo"

type token_operator_param = {
  owner : address;
  fa2 : address;
  token_id : token_id;
  operator : address; 
}

type is_token_operator_response = {
  operator : token_operator_param;
  is_operator : bool;
}

type is_token_operator_param = {
  operators : token_operator_param list;
  view : (is_token_operator_response list) contract;
}

type token_operators_config =
  | Add_token_operators of token_operator_param list
  | Remove_token_operators of token_operator_param list
  | Is_token_operator of is_token_operator_param

(* (owner * (fa2 * token_id)) ->  operators *)
type token_operators = ((address * (address *nat)), (address set)) big_map

type token_operator_policy =
  | Token_operator_permitted of token_operators
  | Token_operator_denied

type op_permission_policy = {
  self: self_transfer_policy;
  operator : token_operator_policy;
  sender : owner_transfer_policy;
  receiver : owner_transfer_policy;
}

let asset_token_operator_config_by_owner_impl (ops : token_operator_param list) : unit =
  let s = Current.sender in
  List.iter 
    (fun (o : token_operator_param) -> 
      if o.owner = s 
      then unit 
      else failwith ("operators change not by owner"))
    ops

let asset_token_operator_config_by_owner (p : token_operators_config) : unit =
  match p with
  | Add_token_operators ops -> asset_token_operator_config_by_owner_impl ops
  | Remove_token_operators ops -> asset_token_operator_config_by_owner_impl ops
  | Is_token_operator p -> unit


let create_operator_key (owner, fa2, token_id : address * address * token_id)
    : (address * (address *nat)) =
  let token = match token_id with
  | Single -> 0n
  | Multi t -> t
  in
  (owner, (fa2, token))

let add_token_operators (ops, operators
    : (token_operator_param list) * token_operators) : token_operators =
  List.fold 
    (fun (os, o : token_operators * token_operator_param) ->
      let key = create_operator_key (o.owner, o.fa2, o.token_id) in
      let owner_ops = 
        match Big_map.find_opt key os with
        | Some o -> o
        | None -> (Set.empty : address set)
      in
      let new_owner_ops = Set.add o.operator owner_ops in
      Big_map.update key (Some new_owner_ops) os)
    ops operators

let remove_token_operators (ops, operators
    : (token_operator_param list) * token_operators) : token_operators =
  List.fold 
    (fun (os, o : token_operators * token_operator_param) ->
      let key = create_operator_key (o.owner, o.fa2, o.token_id) in
      let owner_ops = 
        match Big_map.find_opt key os with
        | Some o -> o
        | None -> (Set.empty : address set)
      in
      let new_owner_ops = Set.remove o.operator owner_ops in
      let update_ops =
        if (Set.size new_owner_ops) = 0n
        then (None : (address set) option)
        else Some new_owner_ops
      in
      Big_map.update key update_ops os)
    ops operators

let is_token_operator (p, ops : is_token_operator_param * token_operators) : operation =
  let responses : is_token_operator_response list = List.map 
    (fun (r : token_operator_param) ->
      let key = create_operator_key (r.owner, r.fa2, r.token_id) in
      let os = Big_map.find_opt key ops in
      let is_op = match os with
      | None -> false
      | Some o -> Set.mem r.operator o
      in
      { operator = r; is_operator = is_op })
    p.operators in
    Operation.transaction responses 0mutez p.view

let configure_token_operators_impl (p, operators
    : token_operators_config * token_operators) : (operation list) * token_operators =
  match p with
  | Add_token_operators ops ->
    let new_operators = add_token_operators (ops, operators) in
    ([] : operation list), new_operators

  | Remove_token_operators ops ->
    let new_operators = remove_token_operators (ops, operators) in
    ([] : operation list), new_operators

  | Is_token_operator p ->
    let op = is_token_operator (p, operators) in
    [op], operators


let configure_token_operators (p, policy
    : token_operators_config * op_permission_policy)
    : (operation list) * op_permission_policy =
  match policy.operator with
  | Token_operator_denied -> 
    (failwith "operators are not supported" : (operation list) * op_permission_policy)
  | Token_operator_permitted ops ->
    let ops, new_operators = configure_token_operators_impl (p, ops) in
    let new_policy = { policy with operator = Token_operator_permitted new_operators; } in
    ops, new_policy

let custom_policy_to_descriptor (p : op_permission_policy) : permission_policy_descriptor =
  let operator = match p.operator with
  | Operator_permitted os ->
    let custom_cfg : custom_permission_policy = {
      tag = "token_operator";
      config_api = Some Current.self_address;
    } in
    Operator_transfer_custom custom_cfg
  | Operator_denied -> Operator_transfer_denied
  in 
  {
    self = p.self;
    operator = operator;
    receiver = p.receiver;
    sender = p.sender;
    custom = (None : custom_permission_policy option);
  }

let custom_validate_operators (p, policy
    : transfer_descriptor_param * op_permission_policy) : unit =

  let operators = match policy.operator with
  | Token_operator_permitted ops -> ops
  | Token_operator_denied -> (Big_map.empty : token_operators)
  in
  let can_self_transfer : bool = match policy.self with
  | Self_transfer_permitted -> true
  | Self_transfer_denied -> false
  in
  let fa2 = Current.sender in
  let can_transfer_from = fun (from_, token_id : address * token_id) ->
     if (can_self_transfer && p.operator = from_)
     then true
     else
      let key = create_operator_key (from_, fa2, token_id) in
      let from_ops = Big_map.find_opt key operators in
      match from_ops with
      |None -> false
      |Some ops -> Set.mem p.operator ops
  in
  List.fold
    (fun (res, tx : bool * transfer_descriptor) ->
      match tx.from_ with
      | None -> res
      | Some addr -> can_transfer_from (addr, tx.token_id))
    p.batch
    true 

let custom_transfer_hook (p, policy : transfer_descriptor_param * op_permission_policy)
    : operation list =
  let u = custom_validate_operators (p, policy) in
  let sender_ops = validate_senders (p, policy.sender) in
  let receiver_ops = validate_receivers (p, policy.receiver) in
  (* merge two lists *)
  List.fold (fun (l, o : (operation list) * operation) -> o :: l) receiver_ops sender_ops

type storage = {
  fa2_registry : fa2_registry;
  policy : op_permission_policy;
}

type  entry_points =
  | Tokens_transferred_hook of transfer_descriptor_param
  | Register_with_fa2 of fa2_with_hook_entry_points contract
  | Config_operators of token_operators_config

let main (param, s : entry_points * storage) 
    : (operation list) * storage =
  match param with
  | Tokens_transferred_hook p ->
    let u = validate_hook_call (Current.sender, s.fa2_registry) in
    let ops = custom_transfer_hook (p, s.policy) in
    ops, s

  | Register_with_fa2 fa2 ->
    let descriptor = custom_policy_to_descriptor s.policy in
    let op , new_registry = register_with_fa2 (fa2, descriptor, s.fa2_registry) in
    let new_s = { s with fa2_registry = new_registry; } in
    [op], new_s

  | Config_operators cfg ->
    let u = match s.policy.self with
    (* assume if self transfers permitted only owner can config its own operators *)
    | Self_transfer_permitted -> asset_token_operator_config_by_owner cfg
    (* assume it is called by the admin *)
    | Self_transfer_denied -> unit
    in
    let ops, new_policy = configure_token_operators (cfg, s.policy) in
    let new_s = { s with policy = new_policy; } in
    ops, new_s