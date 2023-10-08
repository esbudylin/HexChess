use std::collections::HashMap;

use strum_macros::{AsRefStr, EnumIter, EnumString};

#[derive(PartialEq, Eq, Hash, Clone, Copy, EnumIter, EnumString, AsRefStr)]
#[strum(ascii_case_insensitive)]
pub enum ChessmanType {
    Pawn,
    Knight,
    Bishop,
    Rook,
    Queen,
    King,
}

#[derive(Copy, PartialEq, Eq, Hash, Clone, EnumIter, AsRefStr)]
pub enum Color {
    White = 1,
    Black = -1,
}

#[derive(AsRefStr, Copy, Clone)]
pub enum GameOver {
    Draw,
    Stalemate,
    Checkmate,
}

#[derive(Clone, Copy, PartialEq)]
pub struct Chessman {
    pub ctype: ChessmanType,
    pub color: Color,
}

type Promotion = Option<ChessmanType>;

pub type Move = ((i32, i32), (i32, i32), Promotion);

pub type Position = HashMap<(i32, i32), Chessman>;
