// HexChess: the file was modified to suit the bigger board of hexagonal chess.

[<AutoOpen>]
module internal ilf.pgn.PgnParsers.BasicChess

open System 
open FParsec
open ilf.pgn.Data



let fileSymbol = [ 'a' .. 'k'] |> List.map (fun x -> x.ToString())

let findFile (a: string) =
    match a.ToUpper() with
    |"A" -> File.A
    |"B" -> File.B
    |"C" -> File.C
    |"D" -> File.D
    |"E" -> File.E
    |"F" -> File.F
    |"G" -> File.G
    |"H" -> File.H
    |"I" -> File.I
    |"J" -> File.J
    |"K" -> File.K
    | _ -> raise <| System.ArgumentException ("Invalid file letter " + a)

let rankSymbol = [10; 11] @ [1 .. 9] |> List.map (fun x -> x.ToString())

//NOTE: we allow S (ger. "Springer") for knight was used traditionally and is around in older PGNs
//NOTE: 'b' is not allowed here as it is reserved for the b file
let pPiece = 
        (pchar 'p' >>% PieceType.Pawn)
    <|> (pchar 'P' >>% PieceType.Pawn)
    <|> (pchar 'N' >>% PieceType.Knight)
    <|> (pchar 'n' >>% PieceType.Knight)
    <|> (pchar 'S' >>% PieceType.Knight)
    <|> (pchar 's' >>% PieceType.Knight)
    <|> (pchar 'B' >>% PieceType.Bishop)
    <|> (pchar 'R' >>% PieceType.Rook)
    <|> (pchar 'r' >>% PieceType.Rook)
    <|> (pchar 'Q' >>% PieceType.Queen)
    <|> (pchar 'q' >>% PieceType.Queen)
    <|> (pchar 'K' >>% PieceType.King)
    <?> "Piece (N, B, R, Q, K, P, n, r, q, p)"

let pFile =  
    pList(strCI, fileSymbol) |>> findFile
    <?> "File letter (A..K)"

let pRank = 
    pList(strCI, rankSymbol) |>> System.Convert.ToInt32
    <?> "Rank (1..11)"


let apply p = run (pPiece >>. pFile >>. pRank) p