(**
Implementation of the permission transfer hook, which behavior is driven
by a particular settings of `permission_policy`. It is possible to use
additional custom policy "schedule" which let pause/unpause transfers
based on used schedule
*)

#include "fa2_behaviors.mligo"

type schedule_interval = {
  interval : int;
  locked : bool;
}

type schedule = {
  start : timestamp;
  schedule : schedule_interval list;
  cyclic : bool;
}

type schedule_policy = {
  schedule : schedule;
  schedule_interval : int;
}

type extended_policy = {
  standard_policy : permission_policy;
  schedule_policy : schedule_policy option;
}

type storage = {
  fa2_registry : fa2_registry;
  policy : extended_policy;
}

type schedule_config =
  | Set_schedule of schedule
  | View_schedule of (schedule option) contract

let configure_schedule (cfg, policy : schedule_config * schedule_policy option)
    : (operation list) * (schedule_policy option) =
  match cfg with
  | Set_schedule s -> 
    let total_interval = List.fold 
      (fun (t, i : int * schedule_interval) -> t + i.interval)
      s.schedule 0 in
    let new_policy : schedule_policy = { schedule = s; schedule_interval = total_interval; } in
    ([] : operation list), (Some new_policy)
  | View_schedule v ->
    let s = match policy with
    | Some p -> Some p.schedule
    | None -> (None : schedule option)
    in
    let op = Operation.transaction s 0mutez v in
    [op], policy

let custom_policy_to_descriptor (p : extended_policy) : permission_policy_descriptor =
  let standard_descriptor = policy_to_descriptor p.standard_policy in
  match p.schedule_policy with
  | None -> standard_descriptor
  | Some s ->
    let custom_p : custom_permission_policy = {
      tag = "schedule";
      config_api = Some Current.self_address;
    }
    in
    {standard_descriptor with custom = Some custom_p; }

type interval_result =
  | Reminder of int
  | Found of schedule_interval

let is_schedule_locked (policy : schedule_policy) : bool =
  let elapsed : int = Current.time - policy.schedule.start in
  if elapsed > policy.schedule_interval && not policy.schedule.cyclic
  then true
  else (* find schedule interval *)
    let  e = (elapsed mod policy.schedule_interval) + 0 in
    let interval = List.fold 
      (fun (acc, i : interval_result * schedule_interval) ->
        match acc with
        | Found si -> acc
        | Reminder r ->
          if r < i.interval then Found i
          else Reminder (r - i.interval)
      ) policy.schedule.schedule (Reminder e) in
    match interval with
    | Reminder r -> (failwith "schedule logic error" : bool)
    | Found i -> i.locked

let validate_schedule (policy : schedule_policy option) : unit =
  match policy with
  | None -> unit
  | Some p ->
    let locked = is_schedule_locked p in
    if locked
    then failwith "transactions are schedule locked"
    else unit

type  entry_points =
  | Tokens_transferred_hook of transfer_descriptor_param
  | Register_with_fa2 of fa2_with_hook_entry_points contract
  | Config_operators of fa2_operators_config_entry_points
  | Config_schedule of schedule_config

 let main (param, s : entry_points * storage) 
    : (operation list) * storage =
  match param with
  | Tokens_transferred_hook p ->
    let u1 = validate_hook_call (Current.sender, s.fa2_registry) in
    let u2 = validate_schedule(s.policy.schedule_policy) in
    let ops = standard_transfer_hook (p, s.policy.standard_policy) in
    ops, s

  | Register_with_fa2 fa2 ->
    let descriptor = custom_policy_to_descriptor s.policy in
    let op , new_registry = register_with_fa2 (fa2, descriptor, s.fa2_registry) in
    let new_s = { s with fa2_registry = new_registry; } in
    [op], new_s

  | Config_operators cfg ->
    let u = match s.policy.standard_policy.self with
    (* assume if self transfers permitted only owner can config its own operators *)
    | Self_transfer_permitted -> asset_operator_config_by_owner cfg
    (* assume it is called by the admin *)
    | Self_transfer_denied -> unit
    in
    let ops, new_s_policy = configure_operators (cfg, s.policy.standard_policy) in
    let new_s = { s with policy.standard_policy = new_s_policy; } in
    ops, new_s

  | Config_schedule cfg ->
    let ops, new_schedule = configure_schedule (cfg, s.policy.schedule_policy) in
    let new_s = { s with policy.schedule_policy = new_schedule; } in
    ops, new_s

