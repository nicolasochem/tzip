type mint_burn_tx is record
  owner: address;
  amount: nat;
end

type mint_burn_tokens_param is list (mint_burn_tx);

type parameter is
  | Mint_tokens of mint_burn_tokens_param
  | Burn_tokens of mint_burn_tokens_param

type storage is map (address, int);


function parse_mint (var s : storage ; const tx : mint_burn_tx) : storage is
block {
  case s[tx.owner] of
    | None -> s[tx.owner] := int (tx.amount)
    | Some(x) -> s[tx.owner] := x + int (tx.amount)
  end;
} with s


function parse_burn (var s : storage ; const tx : mint_burn_tx) : storage is
block {
  case s[tx.owner] of
    | None -> s[tx.owner] := - int (tx.amount)
    | Some(x) -> s[tx.owner] := x - int (tx.amount)
  end;
} with s


function main(const p: parameter; var s: storage) : (list(operation) * storage) is
  ((nil : list(operation)),
    case p of
      Mint_tokens(txs) -> (List.fold (parse_mint, txs, s))
    | Burn_tokens(txs) -> (List.fold (parse_burn, txs, s))
    end)
