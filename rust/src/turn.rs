use std::collections::{HashMap, HashSet};
use std::iter::repeat;

use itertools::Itertools;
use rayon::prelude::*;
use strum::IntoEnumIterator;

use crate::basics::GameOver;
use crate::{
    basics::{Chessman, ChessmanType, Color, Move, Position},
    board::swap_color,
    mapping::{draw_line, Hor, DIRECTIONS, TILE_COLORS},
    movement::{find_king_threats, pawn_direction},
    variant::Variant,
};

use lazy_static::lazy_static;

lazy_static! {
    static ref POSSIBLE_PROMOTIONS: Vec<ChessmanType> = ChessmanType::iter()
        .filter(|ctype| ctype != &ChessmanType::Pawn && ctype != &ChessmanType::King)
        .collect();
}

#[derive(Copy, PartialEq, Eq, Hash, Clone)]
pub struct MoveMetadata {
    pub moved_chessman: ChessmanType,
    pub capture: Option<ChessmanType>,
}

#[derive(Clone, Copy, PartialEq)]
pub struct EnPassantTile {
    pub target_piece_coords: (i32, i32),
    pub target_tile: (i32, i32),
}

pub struct Turn {
    pub chessmen_placement: Position,
    pub en_passant: Option<EnPassantTile>,
    pub color: Color,
    pub fifty_move_counter: i32,

    pub king_coords: HashMap<Color, (i32, i32)>,
    pub king_threats: Vec<HashSet<(i32, i32)>>,
    pub capture: bool,
    pub position_eval: i32,
    pub able_to_checkmate: bool,

    pub movement: Option<Move>,
    pub possible_moves: Vec<(MoveMetadata, Move)>,
}

impl Turn {
    pub fn new(
        variant: &Variant,
        prev_turn: &Turn,
        (old_position, new_position, promotion): Move,
        chessman_values: &HashMap<ChessmanType, i32>,
    ) -> Turn {
        let mut king_coords = prev_turn.king_coords.clone();
        let mut new_placement = prev_turn.chessmen_placement.clone();

        let chessman = prev_turn.chessmen_placement.get(&old_position).unwrap();

        let moved_piece = match promotion {
            Some(promotion) => Chessman {
                ctype: promotion,
                color: prev_turn.color,
            },
            None => *chessman,
        };

        let mut captured_chessman = new_placement.insert(new_position, moved_piece);

        new_placement.remove(&old_position);

        let mut en_passant = None;
        let mut is_pawn = false;

        let color = swap_color(prev_turn.color);

        match chessman.ctype {
            ChessmanType::Pawn => {
                if let Some(ep) = prev_turn.en_passant {
                    if ep.target_tile == new_position {
                        captured_chessman = new_placement.remove(&ep.target_piece_coords);
                    }
                }
                en_passant = check_for_en_passant(prev_turn.color, old_position, new_position);
                is_pawn = true;
            }
            ChessmanType::King => {
                king_coords.insert(chessman.color, new_position);
            }
            _ => (),
        }

        let mut new_turn = Turn {
            movement: Some((old_position, new_position, promotion)),
            fifty_move_counter: if !(captured_chessman.is_some() || is_pawn) {
                prev_turn.fifty_move_counter + 1
            } else {
                0
            },
            able_to_checkmate: is_able_to_checkmate(&new_placement, color),
            king_threats: find_king_threats(&variant, &new_placement, king_coords[&color], color),

            color,
            en_passant,
            king_coords,

            capture: captured_chessman.is_some(),
            position_eval: -prev_turn.position_eval
                + if let Some(cp) = captured_chessman {
                    chessman_values[&cp.ctype]
                } else {
                    0
                },

            chessmen_placement: new_placement,
            possible_moves: vec![],
        };

        new_turn.find_possible_moves(variant);

        new_turn
    }

    pub fn prototurn(initial_placement: Position, variant: &Variant) -> Turn {
        let mut turn = Turn {
            king_coords: find_kings(&initial_placement),
            chessmen_placement: initial_placement,

            en_passant: None,
            color: Color::White,
            fifty_move_counter: 0,

            capture: false,
            position_eval: 0,
            able_to_checkmate: true,
            movement: None,

            king_threats: vec![],
            possible_moves: vec![],
        };

        turn.find_possible_moves(variant);

        turn
    }

    pub fn is_king_checked(&self) -> bool {
        return !self.king_threats.is_empty();
    }

    fn find_possible_moves(&mut self, variant: &Variant) {
        let moves = self
            .chessmen_placement
            .par_iter()
            .filter_map(|(old_pos, chessman)| {
                if chessman.color == self.color {
                    return Some((*old_pos, chessman.ctype));
                }
                None
            })
            .flat_map(|(old_pos, moved_chessman)| {
                repeat((old_pos, moved_chessman))
                    .zip(variant.find_possible_moves(self, old_pos))
                    .par_bridge()
            })
            .flat_map(|((old_pos, moved_chessman), new_pos)| {
                let capture = if let Some(cap) = self.chessmen_placement.get(&new_pos) {
                    Some(cap.ctype)
                } else {
                    None
                };

                if moved_chessman == ChessmanType::Pawn
                    && variant.promotion_tiles[&self.color].contains(&new_pos)
                {
                    return POSSIBLE_PROMOTIONS
                        .iter()
                        .map(|promotion| {
                            (
                                MoveMetadata {
                                    capture,
                                    moved_chessman,
                                },
                                (old_pos, new_pos, Some(*promotion)),
                            )
                        })
                        .collect_vec();
                } else {
                    return vec![(
                        MoveMetadata {
                            capture,
                            moved_chessman,
                        },
                        (old_pos, new_pos, None),
                    )];
                }
            })
            .collect::<Vec<_>>();

        self.possible_moves = moves;
    }

    pub fn checkmate_stalemate(&self) -> Option<GameOver> {
        return if self.possible_moves.is_empty() {
            if self.is_king_checked() {
                Some(GameOver::Checkmate)
            } else {
                Some(GameOver::Stalemate)
            }
        } else {
            None
        };
    }
}

fn check_for_en_passant(
    color: Color,
    old_position: (i32, i32),
    new_position: (i32, i32),
) -> Option<EnPassantTile> {
    let mut en_passant_tile = None;

    let double_jump = draw_line(
        &DIRECTIONS.adjacent.mapping,
        (Hor::None, pawn_direction(color)),
        old_position,
        Some(3),
    );

    if double_jump.len() == 3 && new_position == *double_jump.last().unwrap() {
        en_passant_tile = Some(EnPassantTile {
            target_piece_coords: new_position,
            target_tile: *double_jump.get(1).unwrap(),
        })
    }

    en_passant_tile
}

fn find_kings(chessmen_placement: &Position) -> HashMap<Color, (i32, i32)> {
    chessmen_placement
        .iter()
        .filter(|(_, chessman)| chessman.ctype == ChessmanType::King)
        .map(|(tile, chessman)| (chessman.color, *tile))
        .collect()
}

fn is_able_to_checkmate(position: &Position, color: Color) -> bool {
    let active_chessmen = position.iter().filter(|(_, piece)| color == piece.color);

    let mut knights = 0;
    let mut bishops_tiles = vec![];

    for (tile, chessman) in active_chessmen {
        match chessman.ctype {
            ChessmanType::Knight => knights += 1,
            ChessmanType::Bishop => bishops_tiles.push(tile),
            ChessmanType::Pawn | ChessmanType::Queen | ChessmanType::Rook => return true,
            ChessmanType::King => (),
        }
    }

    if knights >= 2 {
        return true;
    } else if knights <= 1 && bishops_tiles.len() <= 1 {
        return false;
    } else if knights == 0 && bishops_tiles.len() == 2 {
        return false;
    } else if knights == 0 && bishops_tiles.len() >= 3 {
        let colors = bishops_tiles
            .iter()
            .map(|tile| TILE_COLORS.get(&tile).unwrap())
            .unique()
            .count();

        if colors == 3 {
            return true;
        } else {
            return false;
        }
    }

    true
}
