using Godot;
using System.Linq;
using ilf.pgn.Data;
using Godot.Collections;

public class LoadGame : Node
{
	private readonly string[] gameVariants = new string[] {
		"glinski",
		"mccooey",
		"hexofen"
	};

	public string Variant;

	public Array<string> GameNotation = new Array<string>();
	public Array movesData = new Array();

	public LoadGame(LoadFile file, int gameIdx)
	{
		Game game = file.GameDb.Games[gameIdx];
		var moves = game.MoveText.GetMoves();

		if (game.Tags.ContainsKey("Variant")
			&& gameVariants.Contains(game.Tags["Variant"].ToLower()))
		{
			Variant = game.Tags["Variant"];
		}

		foreach (Move move in moves)
		{
			Array<string> moveData = new Array<string>
			{
				move.Piece.ToString(),
				move.OriginFile.ToString(),
				move.OriginRank.ToString(),
				move.TargetSquare.ToString(),
				move.PromotedPiece.ToString()
			};
			movesData.Add(moveData);
			GameNotation.Add(move.ToString());
		}
	}

}
