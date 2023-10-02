use lazy_static::lazy_static;
use std::collections::HashMap;
use std::str::FromStr;

use gdnative::api::*;
use gdnative::prelude::user_data::MutexData;
use gdnative::prelude::*;

use slab_tree::NodeId;

use crate::mapping::NOTATION_MAP;
use crate::mapping::TILE_COLORS;
use crate::movement::check_tile_for_chessman;
use crate::movement::TileCheck;
use crate::{basics::ChessmanType, board::Board, search::Search, turn::Turn, variant::VariantName};

lazy_static! {
    static ref TILES_BY_COLOR: HashMap<i32, Vec<Vector2>> = tiles_by_color();
}

#[derive(NativeClass)]
#[inherit(Node)]
// we need to use this wrapper to run chess engine on a separate thread inside Godot
#[user_data(MutexData<ChessEngine>)]
pub struct ChessEngine {
    board: Option<Board>,
    turn_seq: Vec<NodeId>,
    chess_ai: Option<Search>,

    current_turn_index: usize,
}

#[derive(ToVariant)]
struct Position {
    coords: Vector2,
    chessman: String,
    color: String,
}

#[derive(ToVariant)]
struct Chessman {
    tile_position: Vector2,
    ctype: String,
}

#[derive(ToVariant)]
struct Notation {
    coords: Vector2,
    notation: String,
}

impl ChessEngine {
    pub fn new(_base: &Node) -> ChessEngine {
        ChessEngine {
            board: None,
            turn_seq: vec![],
            current_turn_index: 0,
            chess_ai: None,
        }
    }
}

#[methods]
impl ChessEngine {
    #[method]
    fn set_board(&mut self, variant: String) {
        self.board = Some(Board::new(VariantName::from_str(&variant).unwrap()));

        self.turn_seq = vec![self.board.as_ref().unwrap().turn_history.root_id().unwrap()];
        self.current_turn_index = 0;
    }

    #[method]
    fn set_negamax(&mut self, chessman_values: HashMap<String, i32>) {
        self.chess_ai = Some(Search::new(
            chessman_values
                .iter()
                .map(|(c, value)| (ChessmanType::from_str(c).unwrap(), *value))
                .collect(),
        ));
    }

    #[method]
    fn find_possible_moves(&self, coords: Vector2) -> Vec<Vector2> {
        self.board
            .as_ref()
            .unwrap()
            .variant
            .find_possible_moves(self.get_current_turn(), (coords.x as i32, coords.y as i32))
            .into_iter()
            .map(|coords| vector2(coords))
            .collect()
    }

    #[method]
    fn get_current_position(&self) -> Vec<Variant> {
        let position = &self.get_current_turn().chessmen_placement;
        position
            .iter()
            .map(|(coords, chessman)| {
                Position {
                    coords: vector2(*coords),
                    chessman: chessman.ctype.as_ref().to_string(),
                    color: chessman.color.as_ref().to_ascii_lowercase(),
                }
                .to_variant()
            })
            .collect()
    }

    #[method]
    fn is_king_checked(&self) -> bool {
        self.get_current_turn().is_king_checked()
    }

    #[method]
    fn check_for_game_over(&self) -> Option<String> {
        let r = self
            .board
            .as_ref()
            .unwrap()
            .check_for_game_over(self.get_node(self.current_turn_index));

        if r.is_some() {
            return Some(r.unwrap().as_ref().into());
        } else {
            None
        }
    }

    #[method]
    fn make_move(
        &mut self,
        old_position: Vector2,
        new_position: Vector2,
        promotion: Option<String>,
    ) {
        let promotion = if let Some(promotion) = promotion {
            Some(ChessmanType::from_str(&promotion).unwrap())
        } else {
            None
        };
        let movement = (
            unpack_vector2(old_position),
            unpack_vector2(new_position),
            promotion,
        );

        let cur_node_id = self.get_node(self.current_turn_index);

        let new_turn = if let Some(next_node_id) = self
            .board
            .as_ref()
            .unwrap()
            .check_if_turn_exists(movement, cur_node_id)
        {
            next_node_id
        } else {
            self.board
                .as_mut()
                .unwrap()
                .add_turn_to_history(movement, cur_node_id)
        };

        self.update_turn_seq(new_turn);
    }

    #[method]
    fn make_computer_move(&mut self, target_depth: f64) -> (Vector2, Option<String>, Variant) {
        let cur_node = self.get_node(self.current_turn_index);

        let new_node = self.chess_ai.as_mut().unwrap().search(
            &mut self.board.as_mut().unwrap(),
            target_depth as usize,
            cur_node,
        );

        let new_turn = self
            .board
            .as_ref()
            .unwrap()
            .turn_history
            .get(new_node)
            .unwrap()
            .data();

        let (old_pos, new_pos, promotion) = new_turn.movement.unwrap();

        let moved_piece = new_turn.chessmen_placement.get(&new_pos).unwrap().ctype;

        self.update_turn_seq(new_node);

        (
            vector2(new_pos),
            match promotion {
                Some(promotion) => Some(promotion.as_ref().to_string()),
                None => None,
            },
            Chessman {
                tile_position: vector2(old_pos),
                ctype: moved_piece.as_ref().to_string(),
            }
            .to_variant(),
        )
    }

    #[method]
    fn check_tile_for_chessman(&self, coords: Vector2) -> Option<Variant> {
        let turn = self.get_current_turn();
        if check_tile_for_chessman(
            &turn.chessmen_placement,
            turn.color,
            &(coords.x as i32, coords.y as i32),
        )
        .0 == TileCheck::SameColor
        {
            let piece = self
                .get_current_turn()
                .chessmen_placement
                .get(&(coords.x as i32, coords.y as i32))
                .unwrap();

            Some(
                Chessman {
                    tile_position: coords,
                    ctype: piece.ctype.as_ref().to_string(),
                }
                .to_variant(),
            )
        } else {
            None
        }
    }

    #[method]
    fn check_ambiguity_util(&self) -> Vec<Vector2> {
        let turn = self.get_turn(self.current_turn_index - 1);

        let (old_position, new_position, _) = self.get_current_turn().movement.unwrap();
        let chessman_type = turn.chessmen_placement[&old_position].ctype;

        turn.chessmen_placement
            .iter()
            .filter_map(|(coords, chessman)| {
                if chessman.ctype == chessman_type
                    && chessman.color == turn.color
                    && *coords != old_position
                    && self
                        .board
                        .as_ref()
                        .unwrap()
                        .variant
                        .find_possible_moves(turn, *coords)
                        .contains(&new_position)
                {
                    return Some(vector2(*coords));
                }
                None
            })
            .collect()
    }

    #[method]
    fn get_current_color(&self) -> String {
        self.get_current_turn().color.as_ref().to_ascii_lowercase()
    }

    #[method]
    fn is_captured(&self) -> bool {
        self.get_current_turn().capture.is_some()
    }

    #[method]
    fn history_length(&self) -> i32 {
        self.turn_seq.len() as i32
    }

    #[method]
    fn get_notation_map() -> Vec<Variant> {
        NOTATION_MAP
            .iter()
            .map(|(coords, notation)| {
                Notation {
                    coords: vector2(*coords),
                    notation: notation.0.to_string() + &notation.1.to_string(),
                }
                .to_variant()
            })
            .collect()
    }

    #[method]
    fn get_tile_colors() -> HashMap<i32, Vec<Vector2>> {
        TILES_BY_COLOR.clone()
    }

    #[method]
    fn get_promotion_tiles(&self) -> HashMap<String, Vec<Vector2>> {
        self.board
            .as_ref()
            .unwrap()
            .variant
            .promotion_tiles
            .clone()
            .into_iter()
            .map(|(color, tiles)| {
                (
                    color.as_ref().to_ascii_lowercase(),
                    tiles
                        .into_iter()
                        .map(|tile: (i32, i32)| vector2(tile))
                        .collect(),
                )
            })
            .collect()
    }

    #[method]
    fn get_current_turn_index(&self) -> i32 {
        self.current_turn_index as i32
    }

    #[method]
    pub fn set_current_turn_index(&mut self, current_turn_index: i32) {
        self.current_turn_index = current_turn_index as usize;
    }
}

impl ChessEngine {
    fn get_current_turn(&self) -> &Turn {
        self.get_turn(self.current_turn_index)
    }

    fn get_turn(&self, id: usize) -> &Turn {
        self.board
            .as_ref()
            .unwrap()
            .turn_history
            .get(self.get_node(id))
            .unwrap()
            .data()
    }

    fn get_node(&self, id: usize) -> NodeId {
        *self.turn_seq.get(id).unwrap()
    }

    fn update_turn_seq(&mut self, new_turn: NodeId) {
        self.turn_seq = self.turn_seq[0..self.current_turn_index + 1].to_vec();
        self.turn_seq.push(new_turn);

        self.current_turn_index = self.turn_seq.len() - 1;
    }
}

fn vector2(coords: (i32, i32)) -> Vector2 {
    Vector2 {
        x: coords.0 as f32,
        y: coords.1 as f32,
    }
}

fn unpack_vector2(vector2: Vector2) -> (i32, i32) {
    (vector2.x as i32, vector2.y as i32)
}

fn tiles_by_color() -> HashMap<i32, Vec<Vector2>> {
    let mut tile_colors = HashMap::new();

    for (coords, color) in TILE_COLORS.clone() {
        tile_colors
            .entry(color)
            .or_insert(vec![])
            .push(vector2(coords));
    }
    tile_colors
}
