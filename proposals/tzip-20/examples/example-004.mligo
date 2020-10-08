type token_def =
[@layout:comb]
{
  from_ : nat;
  to_ : nat;
}

type token_metadata =
[@layout:comb]
{
  token_id : nat;
  symbol : string;
  name : string;
  decimals : nat;
  extras : (string, string) map;
}

type mint_param =
[@layout:comb]
{
  token_def : token_def;
  metadata : token_metadata;
  owners : address list;
}

type parameter =
  | Mint_tokens of mint_param
  | Fallback of unit


type storage = ((address * nat), int) map


let parse_mint (p, s : mint_param * storage) : storage =
  let parse_owner = fun (s, owner : storage * address) ->
    Map.update (owner, p.metadata.token_id) (Some 1) s 
  in
  List.fold parse_owner p.owners s


let main (p, s : parameter * storage) : (operation list) * storage =
  ([] : operation list),
  (match p with
      Mint_tokens (param) -> parse_mint (param, s)
    | Fallback -> s)
