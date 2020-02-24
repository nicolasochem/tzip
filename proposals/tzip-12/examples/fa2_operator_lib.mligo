(** Reference implementation of the FA2 operator storage and config API functions *)

#include "../fa2_interface.mligo"

type operator_tokens_entry =
  | All_operator_tokens
  | Some_operator_tokens of token_id set
  | All_operator_tokens_except of token_id set

(*  (owner * operator) -> tokens *)
type operator_storage = ((address * address), operator_tokens_entry) big_map

(* (owner * operator) -> operator_tokens *)
type grouped_tokens = ((address * address), operator_tokens) map

let merge_tokens (t1, t2 : operator_tokens * operator_tokens) : operator_tokens =
  match t1 with
  | All_tokens -> All_tokens
  | Some_tokens ts1 -> (
    match t2 with
    | All_tokens -> All_tokens
    | Some_tokens ts2 -> (* merge two sets through fold*)
      let new_ts = Set.fold 
        (fun (acc, t : (token_id set) * token_id) -> Set.add t acc)
        ts2 ts1 in
      Some_tokens new_ts
  )

let group_operator_params (ops : operator_param list) : grouped_tokens =
  List.fold
    (fun (g, p : grouped_tokens * operator_param) ->
      let key = p.owner, p.operator in
      let tokens = Big_map.find_opt key g in
      let new_tokens = match tokens with
      | None -> p.tokens
      | Some ts -> merge_tokens (ts, p.tokens)
      in
      Map.update key (Some new_tokens) g
    ) ops (Map.empty : grouped_tokens)


let add_tokens (existing_ts, ts_to_add : (operator_tokens_entry option) * (token_id set))
    : operator_tokens_entry =
  match existing_ts with
  | None -> Some_operator_tokens ts_to_add
  | Some ets -> (
    match ets with
    | All_operator_tokens -> All_operator_tokens
    | Some_operator_tokens ets -> 
      (* merge sets *)
      let new_ts = Set.fold 
        (fun (acc, tid : (token_id set) * token_id) -> Set.add tid acc)
        ts_to_add ets in
      Some_operator_tokens new_ts
    | All_operator_tokens_except ets ->
      (* subtract sets *)
      let new_ts = Set.fold 
        (fun (acc, tid : (token_id set) * token_id) -> Set.remove tid acc)
        ts_to_add ets in
      if (Set.size new_ts) = 0n 
      then All_operator_tokens 
      else All_operator_tokens_except new_ts
  )

let remove_tokens (existing_ts, ts_to_remove : (operator_tokens_entry option) * (token_id set))
    : operator_tokens_entry option =
  match existing_ts with
  | None -> (None : operator_tokens_entry option)
  | Some ets -> (
    match ets with
    | All_operator_tokens -> Some (All_operator_tokens_except ts_to_remove)
    | Some_operator_tokens ets ->
      (* subtract sets *)
      let new_ts = Set.fold 
        (fun (acc, tid : (token_id set) * token_id) -> Set.remove tid acc)
        ts_to_remove ets in
      if (Set.size new_ts) = 0n
      then (None : operator_tokens_entry option)
      else Some (Some_operator_tokens new_ts)
    | All_operator_tokens_except ets ->
       (* merge sets *)
      let new_ts = Set.fold 
        (fun (acc, tid : (token_id set) * token_id) -> Set.add tid acc)
        ts_to_remove ets in
      Some (All_operator_tokens_except new_ts)
  )

let are_tokens_included (existing_tokens, ts : operator_tokens_entry * operator_tokens) : bool =
  match existing_tokens with
  | All_operator_tokens -> true
  | Some_operator_tokens ets -> (
    match ts with
    | All_tokens -> false
    | Some_tokens ots ->
      (* all ots tokens must be in ets set*)
      Set.fold (fun (res, ti : bool * token_id) ->
        if (Set.mem ti ets) then res else false
      ) ots true
  )
  | All_operator_tokens_except ets -> (
    match ts with 
    | All_tokens -> false
    | Some_tokens ots ->
      (* None of the its tokens must be in ets *)
      Set.fold (fun (res, ti : bool * token_id) ->
          if (Set.mem ti ets) then false else res
      ) ots true
  )

let is_operator (p, storage : operator_param * operator_storage) : bool = 
  let key = p.owner, p.operator in
  let op_tokens = Big_map.find_opt key storage in
  match op_tokens with
  | None -> false
  | Some existing_tokens -> are_tokens_included (existing_tokens, p.tokens)

let add_operators (ops, storage : (operator_param list) * operator_storage) : operator_storage =
  let grouped_ops = group_operator_params ops in
  Map.fold
    (fun (s, kv : operator_storage * ((address * address) * operator_tokens) ) ->
      let key, tokens = kv in
      let new_tokens = match tokens with
      | All_tokens -> All_operator_tokens
      | Some_tokens ts_to_add ->
          let existing_tokens = Big_map.find_opt key s in
          add_tokens (existing_tokens, ts_to_add)
      in
      Big_map.update key (Some new_tokens) s
    ) grouped_ops storage

let remove_operators (ops, storage : (operator_param list) * operator_storage) : operator_storage =
  let grouped_ops = group_operator_params ops in
  Map.fold
    (fun (s, kv : operator_storage * ((address * address) * operator_tokens) ) ->
      let key, tokens = kv in
      let new_tokens_opt = match tokens with
      | All_tokens -> (None : operator_tokens_entry option)
      | Some_tokens ts_to_remove ->
          let existing_tokens = Big_map.find_opt key s in
          remove_tokens (existing_tokens, ts_to_remove)
      in
      Big_map.update key new_tokens_opt s
    ) grouped_ops storage

let are_operators (param, storage :  are_operators_param * operator_storage) : operation =
  let responses = List.fold
    (fun (rr, p : (is_operator_response list) * operator_param) ->
      let is_op = is_operator (p, storage) in 
      let r : is_operator_response = { operator = p; is_operator = is_op; } in
      r :: rr
    ) param.operators ([] :is_operator_response list) in
  Operation.transaction responses 0mutez param.view
