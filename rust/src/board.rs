use std::collections::HashMap;

use slab_tree::{NodeId, Tree, TreeBuilder};
use turn::Turn;
use variant::Variant;

use crate::{
    basics::{ChessmanType, Color, GameOver, Move},
    turn::{self},
    variant::{self, VariantName},
};

pub struct Board {
    pub variant: Variant,
    pub turn_history: Tree<Turn>,
    pub chessman_values: HashMap<ChessmanType, i32>,
    pub possible_moves: HashMap<NodeId, Vec<(Option<NodeId>, Move)>>,
}

impl Board {
    pub fn new(name: VariantName, chessman_values: HashMap<ChessmanType, i32>) -> Board {
        let variant = Variant::new(name);
        let prototurn = Turn::prototurn(variant.initial_position.clone(), &variant);
        let turn_history = TreeBuilder::new().with_root(prototurn).build();

        Self {
            turn_history,
            variant,
            chessman_values,
            possible_moves: HashMap::new()
        }
    }

    pub fn add_turn_to_history(&mut self, movement: Move, parent_id: NodeId) -> NodeId {
        let prev_turn = self.turn_history.get(parent_id).unwrap().data();
        let new_turn = Turn::new(
            &self.variant,
            prev_turn,
            movement,
            &self.chessman_values,
        );

        self.turn_history
            .get_mut(parent_id)
            .unwrap()
            .append(new_turn)
            .node_id()
    }

    pub fn check_if_turn_exists(&self, movement: Move, parent_id: NodeId) -> Option<NodeId> {
        let node = self.turn_history.get(parent_id).unwrap();
        let mut children = node.children();

        while let Some(child) = children.next() {
            let turn = child.data();
            if turn.movement == Some(movement) {
                return Some(child.node_id());
            }
        }

        None
    }

    pub fn check_for_game_over(&self, turn_idx: NodeId) -> Option<GameOver> {
        let turn_node = self.turn_history.get(turn_idx).unwrap();
        let turn = turn_node.data();
        let checkmate_stalemate = turn.checkmate_stalemate();

        if checkmate_stalemate.is_some() {
            return checkmate_stalemate;
        }

        if let Some(parent) = turn_node.parent() {
            if turn.color == Color::White && turn.fifty_move_counter >= 100
                || self.threefold_rule(turn, turn_idx)
                || !turn.able_to_checkmate && !parent.data().able_to_checkmate
            {
                return Some(GameOver::Draw);
            }
        }

        None
    }

    fn threefold_rule(&self, turn: &Turn, turn_idx: NodeId) -> bool {
        let mut turn_idx = turn_idx;
        let mut counter = 0;

        loop {
            let cur_turn = self.turn_history.get(turn_idx).unwrap();

            if let Some(par) = cur_turn.parent() {
                if let Some(grandparent) = par.parent() {
                    let (grandparent_id, grandparent_turn) =
                        (grandparent.node_id(), grandparent.data());

                    if grandparent_turn.chessmen_placement == turn.chessmen_placement
                        && grandparent_turn.en_passant == turn.en_passant
                    {
                        counter += 1;
                    }

                    if counter == 2 {
                        return true;
                    }

                    turn_idx = grandparent_id;

                    continue;
                }
            }

            break;
        }

        false
    }
}

pub fn swap_color(color: Color) -> Color {
    match color {
        Color::White => Color::Black,
        Color::Black => Color::White,
    }
}
