use std::collections::HashSet;

use itertools::Itertools;

use crate::{
    basics::{Chessman, ChessmanType, Color, Position},
    board::swap_color,
    mapping::{Direction, Hor, MapId, Ver, DIRECTIONS, TILE_PAIRS_TO_DIRS},
    turn::{EnPassantTile, Turn},
    variant::Variant,
};

#[derive(PartialEq)]
pub enum TileCheck {
    None,
    DifColor,
    SameColor,
}

impl Variant {
    pub fn find_possible_moves(&self, turn: &Turn, origin: (i32, i32)) -> HashSet<(i32, i32)> {
        let chessman_to_move = turn.chessmen_placement.get(&origin).unwrap();

        let is_king = chessman_to_move.ctype == ChessmanType::King;

        let basic_movement = self.basic_movement(
            &turn.chessmen_placement,
            turn.color,
            chessman_to_move,
            origin,
            turn.en_passant,
        );

        let pin_area = find_pin_area(&turn, origin);

        if !is_king {
            match turn.king_threats.len() {
                0 => {
                    if pin_area.is_empty() {
                        return basic_movement;
                    } else {
                        return basic_movement.intersection(&pin_area).copied().collect();
                    }
                }
                1 => {
                    if pin_area.is_empty() {
                        let threat = turn.king_threats.get(0).unwrap();

                        return basic_movement.intersection(threat).copied().collect();
                    } else {
                        return HashSet::new();
                    }
                }
                _ => return HashSet::new(),
            }
        } else {
            return self.king_movement(turn, chessman_to_move, origin);
        }
    }

    fn basic_movement(
        &self,
        position: &Position,
        active_color: Color,
        chessman: &Chessman,
        tile: (i32, i32),
        en_passant_check: Option<EnPassantTile>,
    ) -> HashSet<(i32, i32)> {
        let mut result = HashSet::new();

        match chessman.ctype {
            ChessmanType::Knight => return knight_movement(position, active_color, tile),
            ChessmanType::Pawn => {
                return self.pawn_movement(position, chessman.color, tile, en_passant_check)
            }
            _ => {
                let length = if chessman.ctype == ChessmanType::King {
                    Some(1)
                } else {
                    None
                };

                let movement = |mapping_id, dirs: &Vec<(Hor, Ver)>| {
                    dirs.iter()
                        .flat_map(|dir| {
                            check_direction(
                                position,
                                active_color,
                                tile,
                                (mapping_id, *dir),
                                length,
                                true,
                            )
                        })
                        .collect::<Vec<_>>()
                };

                if chessman.ctype != ChessmanType::Bishop {
                    result.extend(movement(
                        DIRECTIONS.adjacent.id,
                        &DIRECTIONS.adjacent.directions,
                    ))
                }
                if chessman.ctype != ChessmanType::Rook {
                    result.extend(movement(
                        DIRECTIONS.bishop.id,
                        &DIRECTIONS.bishop.directions,
                    ))
                }
                result
            }
        }
    }

    fn pawn_movement(
        &self,
        position: &Position,
        color: Color,
        tile: (i32, i32),
        en_passant_check: Option<EnPassantTile>,
    ) -> HashSet<(i32, i32)> {
        let ver = pawn_direction(color);
        let length = self.pawn_movement_length(tile, color);

        let mut result = check_direction(
            position,
            color,
            tile,
            (DIRECTIONS.adjacent.id, (Hor::None, ver)),
            Some(length),
            false,
        );
        result.extend(self.pawn_attack(position, color, tile, en_passant_check));

        return result;
    }

    fn pawn_movement_length(&self, tile: (i32, i32), color: Color) -> i32 {
        if self.double_jump_tiles[&color].contains(&tile) {
            return 2;
        } else {
            return 1;
        };
    }

    fn pawn_threat(&self, color: Color, tile: (i32, i32)) -> HashSet<(i32, i32)> {
        let ver = pawn_direction(color);

        let directions = vec![(Hor::Left, ver), (Hor::Right, ver)];

        let mapping = match self.pawn_movement {
            MapId::Adjacent => &DIRECTIONS.adjacent.mapping,
            MapId::Bishop => &DIRECTIONS.bishop.mapping,
        };

        directions
            .iter()
            .filter_map(|dir| {
                if let Some(tile) = mapping.get(&tile).unwrap().get(dir) {
                    Some(*tile)
                } else {
                    None
                }
            })
            .collect()
    }

    fn pawn_attack(
        &self,
        position: &Position,
        color: Color,
        tile: (i32, i32),
        en_passant_check: Option<EnPassantTile>,
    ) -> HashSet<(i32, i32)> {
        self.pawn_threat(color, tile)
            .into_iter()
            .filter_map(|new_pos| {
                if check_tile_for_chessman(position, color, &new_pos).0 == TileCheck::DifColor
                    || en_passant_check.is_some()
                        && en_passant_check.unwrap().target_tile == new_pos
                {
                    Some(new_pos)
                } else {
                    None
                }
            })
            .collect()
    }

    fn king_movement(
        &self,
        turn: &Turn,
        king: &Chessman,
        origin: (i32, i32),
    ) -> HashSet<(i32, i32)> {
        let mut position_without_king = turn.chessmen_placement.clone();
        position_without_king.remove_entry(&turn.king_coords[&king.color]);

        self.basic_movement(&turn.chessmen_placement, turn.color, king, origin, None)
            .into_iter()
            .filter(|tile| {
                find_king_threats(&self, &position_without_king, *tile, king.color).len() == 0
            })
            .collect()
    }
}

fn knight_movement(position: &Position, color: Color, tile: (i32, i32)) -> HashSet<(i32, i32)> {
    DIRECTIONS
        .knight
        .get(&tile)
        .unwrap()
        .iter()
        .filter(
            |tile| match check_tile_for_chessman(position, color, tile).0 {
                TileCheck::None | TileCheck::DifColor => true,
                TileCheck::SameColor => false,
            },
        )
        .map(|t| *t)
        .collect()
}

pub fn pawn_direction(color: Color) -> Ver {
    match color {
        Color::White => return Ver::Up,
        Color::Black => return Ver::Down,
    };
}

fn check_direction(
    position: &Position,
    color: Color,
    origin: (i32, i32),
    dir: Direction,
    length: Option<i32>,
    capture: bool,
) -> HashSet<(i32, i32)> {
    let l = length.unwrap_or(10);
    let mut result = HashSet::new();
    let mut pos = &origin;

    let tile_map = match dir.0 {
        MapId::Adjacent => &DIRECTIONS.adjacent.mapping,
        MapId::Bishop => &DIRECTIONS.bishop.mapping,
    };

    for _ in 0..l {
        match tile_map.get(pos).and_then(|dirs| dirs.get(&dir.1)) {
            Some(new_pos) => {
                let tile_check = check_tile_for_chessman(position, color, new_pos);

                match tile_check.0 {
                    TileCheck::None => {
                        result.insert(*new_pos);
                        pos = new_pos;
                    }

                    TileCheck::DifColor => {
                        if capture {
                            result.insert(*new_pos);
                        }
                        return result;
                    }

                    TileCheck::SameColor => {
                        break;
                    }
                }
            }
            None => break,
        }
    }

    result
}

pub fn check_tile_for_chessman(
    position: &Position,
    color: Color,
    tile: &(i32, i32),
) -> (TileCheck, Option<ChessmanType>) {
    return match position.get(tile) {
        Some(chessman) => {
            return (
                if chessman.color != color {
                    TileCheck::DifColor
                } else {
                    TileCheck::SameColor
                },
                Some(chessman.ctype),
            )
        }
        None => (TileCheck::None, None),
    };
}

fn find_pin_area(turn: &Turn, origin: (i32, i32)) -> HashSet<(i32, i32)> {
    let king_dir = TILE_PAIRS_TO_DIRS.get(&(origin, turn.king_coords[&turn.color]));

    if let Some(king_dir) = king_dir {
        if turn
            .chessmen_placement
            .iter()
            .filter_map(|(tile, _)| {
                return if king_dir.tiles.contains(tile) {
                    Some(tile)
                } else {
                    None
                };
            })
            .count()
            == 1
        {
            let opp_chessman = turn
                .chessmen_placement
                .iter()
                .filter_map(
                    |(tile, chessman)| match TILE_PAIRS_TO_DIRS.get(&(*tile, origin)) {
                        Some(line) => match line.dir == king_dir.dir {
                            true => Some((line, chessman)),
                            false => None,
                        },
                        None => None,
                    },
                )
                .sorted_by_key(|a| &a.0.len)
                .next();

            if let Some(opp_chessman) = opp_chessman {
                if opp_chessman.1.color != turn.color {
                    match (opp_chessman.1.ctype, opp_chessman.0.dir.0) {
                        (ChessmanType::Queen, _)
                        | (ChessmanType::Bishop, MapId::Bishop)
                        | (ChessmanType::Rook, MapId::Adjacent) => {
                            return opp_chessman.0.tiles.clone()
                        }
                        _ => return HashSet::new(),
                    }
                }
            }
        }
    }

    HashSet::new()
}

pub fn find_king_threats(
    variant: &Variant,
    position: &Position,
    king_coords: (i32, i32),
    color: Color,
) -> Vec<HashSet<(i32, i32)>> {
    let dir_as_key = |dir: Direction| (dir.0 as i32, dir.1 .0 as i32, dir.1 .1 as i32);

    position
        .iter()
        .filter_map(
            |(tile, chessman)| match TILE_PAIRS_TO_DIRS.get(&(*tile, king_coords)) {
                Some(line) => Some((line, *chessman)),
                None => None,
            },
        )
        .sorted_by_key(|(line, _)| dir_as_key(line.dir))
        .group_by(|(line, _)| line.dir)
        .into_iter()
        .map(|(_, group)| {
            group
                .into_iter()
                .sorted_by_key(|(line, _)| line.len)
                .next()
                .unwrap()
        })
        .filter_map(|(line, chessman)| {
            return if chessman.color == color {
                None
            } else {
                match (chessman.ctype, line.dir.0) {
                    (ChessmanType::Pawn, pawn_map) => {
                        if variant.pawn_movement == pawn_map
                            && line.len == 1
                            && pawn_direction(swap_color(color)) == line.dir.1 .1
                            && line.dir.1 .0 != Hor::None
                        {
                            Some(line.tiles.clone())
                        } else {
                            None
                        }
                    }

                    (ChessmanType::Queen, _)
                    | (ChessmanType::Bishop, MapId::Bishop)
                    | (ChessmanType::Rook, MapId::Adjacent) => Some(line.tiles.clone()),

                    (ChessmanType::King, _) => {
                        if line.len == 1 {
                            Some(line.tiles.clone())
                        } else {
                            None
                        }
                    }

                    _ => None,
                }
            };
        })
        .chain(
            DIRECTIONS
                .knight
                .get(&king_coords)
                .unwrap()
                .iter()
                .filter_map(|tile| {
                    return if check_tile_for_chessman(position, color, tile)
                        == (TileCheck::DifColor, Some(ChessmanType::Knight))
                    {
                        Some(HashSet::from([*tile]))
                    } else {
                        None
                    };
                }),
        )
        .collect_vec()
}
