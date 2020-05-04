#include "../fa2_hook.mligo"

let permissions_descriptor_to_michelson (d : permissions_descriptor)
    : permissions_descriptor_michelson =
  let aux : permissions_descriptor_aux = {
    operator = Layout.convert_to_right_comb d.operator;
    receiver = Layout.convert_to_right_comb d.receiver;
    sender = Layout.convert_to_right_comb d.sender;
    custom = match d.custom with
    | None -> (None : custom_permission_policy_michelson option)
    | Some c -> Some (Layout.convert_to_right_comb c)
  } in
  Layout.convert_to_right_comb aux

let transfer_descriptor_param_to_michelson (p : transfer_descriptor_param)
    : transfer_descriptor_param_michelson =
  let aux : transfer_descriptor_param_aux = {
    fa2 = p.fa2;
    operator = p.operator;
    batch = List.map 
      (fun (td: transfer_descriptor) -> Layout.convert_to_right_comb td) 
      p.batch;
  } in
  Layout.convert_to_right_comb aux

let transfer_descriptor_param_from_michelson (p : transfer_descriptor_param_michelson)
    : transfer_descriptor_param =
  let aux : transfer_descriptor_param_aux = Layout.convert_from_right_comb p in
  let b : transfer_descriptor list = List.map 
      (fun (tdm : transfer_descriptor_michelson) -> 
        let td : transfer_descriptor = Layout.convert_from_right_comb tdm in
        td
      )
      aux.batch
  in
  {
    fa2 = aux.fa2;
    operator = aux.operator;
    batch = b;
  }