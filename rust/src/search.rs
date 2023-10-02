use std::{cmp::Ordering, collections::HashMap};

use itertools::Itertools;
use slab_tree::NodeId;

use crate::{
    basics::{ChessmanType, Color, GameOver, Move},
    board::Board,
    turn::{MoveMetadata, Position, Turn},
};

enum SearchDir {
    Up,
    Down,
}

const EVAL_MAX: i32 = 1000;

struct SearchState {
    best_score: i32,
    best_depth: Option<usize>,

    alpha: i32,
    beta: i32,

    best_move: Option<NodeId>,

    available_moves: usize,
    cur_move: usize,
}

impl SearchState {
    fn new(parent: &SearchState, available_moves: usize) -> SearchState {
        SearchState {
            best_score: -EVAL_MAX,
            best_depth: None,

            alpha: -parent.beta,
            beta: -parent.alpha,

            best_move: None,

            cur_move: 0,
            available_moves,
        }
    }

    fn protoparent() -> SearchState {
        SearchState {
            best_score: -EVAL_MAX,
            best_depth: None,

            alpha: -EVAL_MAX,
            beta: EVAL_MAX,

            best_move: None,

            cur_move: 0,
            available_moves: 0,
        }
    }

    fn should_update_score(&self, new_score: i32, new_depth: usize) -> bool {
        match new_score.cmp(&self.best_score) {
            Ordering::Less => false,
            Ordering::Greater => true,
            Ordering::Equal => {
                if let Some(pr_depth) = self.best_depth {
                    if new_score > 0 {
                        return new_depth < pr_depth;
                    } else {
                        return new_depth > pr_depth;
                    }
                } else {
                    return true;
                }
            }
        }
    }

    fn should_prune(&self) -> bool {
        self.alpha < EVAL_MAX && self.alpha >= self.beta
    }

    fn update_score(&mut self, new_score: i32, new_depth: usize, new_move: NodeId) {
        self.best_score = new_score;
        self.best_depth = Some(new_depth);
        self.best_move = Some(new_move);
    }
}

pub struct Search {
    chessman_values: HashMap<ChessmanType, i32>,
    possible_moves: HashMap<NodeId, Vec<(Option<NodeId>, Move)>>,
}

impl Search {
    pub fn new(chessman_values: HashMap<ChessmanType, i32>) -> Self {
        Self {
            chessman_values,
            possible_moves: HashMap::new(),
        }
    }

    pub fn search(&mut self, board: &mut Board, target_depth: usize, root: NodeId) -> NodeId {
        // the function is roughly based on the Non Recursive Negamax implementation from the pythonic EasyAI library;
        // see: https://github.com/Zulko/easyAI/blob/master/easyAI/AI/NonRecursiveNegamax.py

        let mut dir = SearchDir::Down;

        let mut cur_turn_id = root;

        let mut states = (0..target_depth)
            .map(|_| SearchState::protoparent())
            .collect_vec();

        let mut depth = 0;

        loop {
            match dir {
                SearchDir::Down => {
                    let game_over = board.check_for_game_over(cur_turn_id);

                    depth += 1;

                    if depth < target_depth && game_over.is_none() {
                        let parent = states.get(depth - 1).unwrap();

                        let moves = self
                            .possible_moves
                            .entry(cur_turn_id)
                            .or_insert(transform_possible_moves(
                                board.turn_history.get(cur_turn_id).unwrap().data(),
                                &self.chessman_values,
                            ))
                            .len()
                            - 1;

                        states[depth] = SearchState::new(parent, moves);

                        cur_turn_id = self.make_move(board, &mut states[depth], cur_turn_id);
                    } else {
                        let parent = states.get_mut(depth - 1).unwrap();

                        let turn = board.turn_history.get(cur_turn_id).unwrap().data();

                        let score = -match game_over {
                            Some(game_over) => match game_over {
                                GameOver::Checkmate => -EVAL_MAX,
                                GameOver::Draw | GameOver::Stalemate => 0,
                            },
                            None => self.eval_position(
                                &turn.chessmen_placement,
                                turn.color,
                                turn.possible_moves.len(),
                            ),
                        };

                        if parent.should_update_score(score, depth) {
                            parent.update_score(score, depth, cur_turn_id);
                        }

                        if parent.alpha < score {
                            parent.alpha = score;
                        }

                        dir = SearchDir::Up;
                    }
                }
                SearchDir::Up => {
                    depth -= 1;

                    let (left, right) = states.split_at_mut(depth);

                    let state = &mut right[0];

                    cur_turn_id = board
                        .turn_history
                        .get(cur_turn_id)
                        .unwrap()
                        .parent()
                        .unwrap()
                        .node_id();

                    if state.cur_move >= state.available_moves || state.should_prune() {
                        let mut parent = &mut left[depth - 1];

                        let score = -state.best_score;

                        if parent.should_update_score(score, state.best_depth.unwrap()) {
                            parent.update_score(score, state.best_depth.unwrap(), cur_turn_id);
                        }

                        if parent.alpha < score {
                            parent.alpha = score;
                        }

                        if depth <= 1 {
                            break;
                        }

                        dir = SearchDir::Up;
                    } else {
                        cur_turn_id = self.make_move(board, state, cur_turn_id);

                        dir = SearchDir::Down;
                    }
                }
            }
        }

        states[1].best_move.unwrap()
    }

    fn make_move(
        &mut self,
        board: &mut Board,
        state: &mut SearchState,
        parent_id: NodeId,
    ) -> NodeId {
        let (node, movement) = self.possible_moves[&parent_id][state.cur_move];

        let new_node = match node {
            Some(node) => node,
            None => {
                let new_node = board.add_turn_to_history(movement, parent_id);

                self.possible_moves
                    .get_mut(&parent_id)
                    .unwrap()
                    .get_mut(state.cur_move)
                    .unwrap()
                    .0 = Some(new_node);

                new_node
            }
        };

        state.cur_move += 1;

        new_node
    }

    fn eval_position(&self, position: &Position, color: Color, mobility: usize) -> i32 {
        position.iter().fold(0, |acc, (_, el)| {
            acc + self.chessman_values[&el.ctype] * el.color as i32 * 10
        }) * color as i32
            + 1 * mobility as i32
    }
}

fn transform_possible_moves(
    turn: &Turn,
    chessman_values: &HashMap<ChessmanType, i32>,
) -> Vec<(Option<NodeId>, Move)> {
    turn.possible_moves
        .iter()
        .sorted_unstable_by_key(
            |(
                MoveMetadata {
                    capture,
                    moved_chessman,
                },
                _,
            )| {
                (
                    match capture {
                        Some(capture) => -*chessman_values.get(&capture).unwrap(),
                        None => 0,
                    },
                    *chessman_values.get(moved_chessman).unwrap(),
                )
            },
        )
        .map(|(_, movement)| (None, *movement))
        .collect_vec()
}
