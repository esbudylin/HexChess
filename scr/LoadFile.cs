using Godot;
using System.Linq;
using ilf.pgn;
using ilf.pgn.Data;
using ilf.pgn.Exceptions;

public class LoadFile : Node
{

	public readonly Database GameDb;
	public readonly int GamesAmount;

	public LoadFile(string savePath)
	{
		var reader = new PgnReader();
		try
		{
			GameDb = reader.ReadFromFile(savePath);
			GamesAmount = GameDb.Games.Count();
		}
		catch (PgnFormatException)
		{
			GamesAmount = -1;
		}
	}


}
