type mint_burn_tx =
[@layout:comb]
{
  owner : address;
  token_id : nat;
  amount : nat;
}

type mint_burn_tokens_param = mint_burn_tx list

type parameter =
  | Mint_tokens of mint_burn_tokens_param
  | Burn_tokens of mint_burn_tokens_param

type storage = ((address * nat), int) map


let parse_mint (s, tx : storage * mint_burn_tx) =
  let existing_amount = Map.find_opt (tx.owner, tx.token_id) s in
  let delta = match existing_amount with
      | None -> int (tx.amount)
      | Some x -> x + int (tx.amount)
  in
  Map.update (tx.owner, tx.token_id) (Some delta) s


let parse_burn (s, tx : storage * mint_burn_tx) =
  let existing_amount = Map.find_opt (tx.owner, tx.token_id) s in
  let delta = match existing_amount with
      | None -> - int (tx.amount)
      | Some x -> x - int (tx.amount)
  in
  Map.update (tx.owner, tx.token_id) (Some delta) s


let main (p, s : parameter * storage) : (operation list) * storage =
  ([] : operation list),
  (match p with
      Mint_tokens (txs) -> List.fold parse_mint txs s
    | Burn_tokens (txs) -> List.fold parse_burn txs s)
