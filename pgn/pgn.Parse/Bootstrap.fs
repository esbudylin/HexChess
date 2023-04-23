// HexChess: the file was modified to remove debug code.

[<AutoOpen>]
module ilf.pgn.PgnParsers.Bootstrap

open System

let toNullable =
    function
    | None -> Nullable()
    | Some x -> Nullable(x)