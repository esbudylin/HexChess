use std::collections::{HashMap, HashSet};
use std::iter::zip;

use strum::IntoEnumIterator;
use strum_macros::{AsRefStr, EnumString};

use crate::mapping::MapId;
use crate::{basics::Chessman, basics::ChessmanType, basics::Color, turn::Position};

#[derive(Clone, Copy, EnumString, PartialEq, AsRefStr)]
#[strum(ascii_case_insensitive)]
pub enum VariantName {
    Glinski,
    Mccooey,
    Hexofen,
}

#[derive(Clone)]
pub struct Variant {
    pub name: VariantName,
    pub initial_position: Position,
    pub pawn_movement: MapId,
    pub promotion_tiles: HashMap<Color, HashSet<(i32, i32)>>,
    pub double_jump_tiles: HashMap<Color, Vec<(i32, i32)>>,
}

impl Variant {
    pub fn new(name: VariantName) -> Variant {
        use crate::initial_positions::initial_positions;
        use crate::initial_positions::find_promotion_tiles;

        let mut initial_position = HashMap::new();
        let mut double_jump_tiles: HashMap<Color, Vec<(i32, i32)>> = HashMap::new();

        let double_jump_exception =
            |tile: (i32, i32)| -> bool { VariantName::Mccooey == name && tile.0 == 0 };

        for (ctype, pos) in zip(ChessmanType::iter(), initial_positions(&name)) {
            for p in pos {
                let color = if p.1 > 0 { Color::White } else { Color::Black };
                initial_position.insert(
                    p,
                    Chessman {
                        ctype: ctype,
                        color: color,
                    },
                );
                if ChessmanType::Pawn == ctype && !double_jump_exception(p) {
                    double_jump_tiles.entry(color).or_insert(vec![]).push(p);
                }
            }
        }

        Self {
            promotion_tiles: find_promotion_tiles(name),
            pawn_movement: match name {
                VariantName::Glinski => MapId::Adjacent,
                VariantName::Mccooey | VariantName::Hexofen => MapId::Bishop,
            },
            initial_position,
            double_jump_tiles,
            name,
        }
    }
}
