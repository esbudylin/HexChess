use lazy_static::lazy_static;
use std::collections::{HashMap, HashSet};

lazy_static! {
    static ref BOARD_TILES: HashSet<(i32, i32)> = find_tiles_in_range((0, 0), 5);
    pub static ref DIRECTIONS: TileMappings = map_possible_moves();
    pub static ref TILE_COLORS: HashMap<(i32, i32), i32> = find_tile_colors();
    pub static ref NOTATION_MAP: HashMap<(i32, i32), (char, i32)> = map_coords_to_notation();
    pub static ref TILE_PAIRS_TO_DIRS: HashMap<((i32, i32), (i32, i32)), Line> =
        map_tile_pairs_to_directions();
}

pub type Direction = (MapId, (Hor, Ver));

pub struct Line {
    pub len: usize,
    pub tiles: HashSet<(i32, i32)>,
    pub dir: Direction,
}

#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub enum MapId {
    Adjacent,
    Bishop,
}

#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub enum Ver {
    None,
    Up = -1,
    Down = 1,
}

#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub enum Hor {
    None,
    Left = -1,
    Right = 1,
}

pub type TileMap = HashMap<(i32, i32), HashMap<(Hor, Ver), (i32, i32)>>;

pub struct TileMappings {
    pub bishop: Mapping,
    pub adjacent: Mapping,
    pub knight: HashMap<(i32, i32), HashSet<(i32, i32)>>,
}

pub struct Mapping {
    pub id: MapId,
    pub directions: Vec<(Hor, Ver)>,
    pub mapping: TileMap,
}

fn find_closest_tiles((x, y): (i32, i32)) -> [(i32, i32); 6] {
    let i = if x % 2 != 0 { 1 } else { -1 };

    [
        (x + 1, y + i),
        (x + 1, y),
        (x, y - 1),
        (x - 1, y),
        (x - 1, y + i),
        (x, y + 1),
    ]
}

fn find_tiles_in_range(coords: (i32, i32), range: i32) -> HashSet<(i32, i32)> {
    let mut tiles = HashSet::from([coords]);
    let mut neighbors = [coords].to_vec();

    for _ in 0..range {
        neighbors = neighbors
            .into_iter()
            .flat_map(|tile| find_closest_tiles(tile))
            .filter(|tile| !tiles.contains(tile))
            .collect::<Vec<_>>();

        tiles.extend(&neighbors);
    }

    tiles
}

fn adjacent_tile((x, y): (i32, i32), dir: (Hor, Ver)) -> (i32, i32) {
    let hor = dir.0 as i32;
    let ver = dir.1 as i32;

    if ver != 0 && hor != 0 {
        if x % 2 == 0 && ver == -1 || x % 2 != 0 && ver == 1 {
            return (x + hor, y + ver);
        } else {
            return (x + hor, y);
        }
    } else if ver != 0 {
        return (x, y + ver);
    } else {
        panic!()
    }
}

fn bishop_adjacent_tile((x, y): (i32, i32), dir: (Hor, Ver)) -> (i32, i32) {
    let hor = dir.0 as i32;
    let ver = dir.1 as i32;

    if ver == 1 && x % 2 != 0 || ver == -1 && x % 2 == 0 {
        return (x + hor, y + ver * 2);
    } else if ver != 0 {
        return (x + hor, y + ver);
    } else if hor != 0 {
        return (x + hor * 2, y);
    } else {
        panic!()
    }
}

pub fn draw_line(
    mapping: &TileMap,
    dir: (Hor, Ver),
    origin: (i32, i32),
    length: Option<i32>,
) -> Vec<(i32, i32)> {
    let mut line = vec![origin];
    let length = length.unwrap_or(11);

    for i in 0..length - 1 {
        match mapping
            .get(line.get(i as usize).unwrap())
            .and_then(|dirs| dirs.get(&dir))
        {
            Some(pos) => line.push(*pos),
            None => break,
        }
    }

    line
}

fn map_possible_moves() -> TileMappings {
    let map_tiles_to_neighbors =
        |f: fn((i32, i32), (Hor, Ver)) -> (i32, i32), dirs: &Vec<(Hor, Ver)>| -> TileMap {
            let mut mapped_board = HashMap::new();

            for tile in BOARD_TILES.iter() {
                let mut mapped_tile = HashMap::new();
                for d in dirs {
                    let l = f(*tile, *d);
                    if BOARD_TILES.contains(&l) {
                        mapped_tile.insert(*d, l);
                    }
                }
                mapped_board.insert(*tile, mapped_tile);
            }

            mapped_board
        };

    let map_knight_moves = |(x, y): (i32, i32)| {
        let mut moves = vec![(-2, -2), (3, 0), (-2, 2), (2, 2), (2, -2), (-3, 0)];
        if x % 2 == 0 {
            moves.extend([(-1, -2), (-1, 3), (1, 3), (1, -2), (3, 1), (-3, 1)].iter());
        } else {
            moves.extend([(3, -1), (-1, 2), (1, 2), (-3, -1), (-1, -3), (1, -3)].iter())
        };

        moves
            .iter()
            .map(|m| (x - m.0, y - m.1))
            .filter(|t| BOARD_TILES.contains(t))
            .collect::<HashSet<(i32, i32)>>()
    };

    let neighbors_dirs: Vec<(Hor, Ver)> = vec![
        (Hor::Left, Ver::Up),
        (Hor::Left, Ver::Down),
        (Hor::Right, Ver::Up),
        (Hor::Right, Ver::Down),
        (Hor::None, Ver::Up),
        (Hor::None, Ver::Down),
    ];

    let bishop_dirs: Vec<(Hor, Ver)> = vec![
        (Hor::Left, Ver::Up),
        (Hor::Left, Ver::Down),
        (Hor::Right, Ver::Up),
        (Hor::Right, Ver::Down),
        (Hor::Right, Ver::None),
        (Hor::Left, Ver::None),
    ];

    TileMappings {
        bishop: Mapping {
            id: MapId::Bishop,
            mapping: map_tiles_to_neighbors(bishop_adjacent_tile, &bishop_dirs),
            directions: bishop_dirs,
        },
        adjacent: Mapping {
            id: MapId::Adjacent,
            mapping: map_tiles_to_neighbors(adjacent_tile, &neighbors_dirs),
            directions: neighbors_dirs,
        },
        knight: BOARD_TILES
            .iter()
            .map(|tile| (*tile, map_knight_moves(*tile)))
            .collect(),
    }
}

fn find_tile_colors() -> HashMap<(i32, i32), i32> {
    let start_tiles = [(1, -1), (1, 0), (0, 0)];

    let mut color_map = HashMap::new();

    let adjacent = |tile: &(i32, i32)| DIRECTIONS.bishop.mapping.get(tile).unwrap().values();

    let search = |start_tile: (i32, i32)| {
        let mut stack = vec![start_tile];
        let mut result = vec![start_tile];
        let mut discovered = HashSet::new();

        while let Some(v) = stack.pop() {
            if discovered.insert(v) {
                for w in adjacent(&v) {
                    stack.push(*w);
                    result.push(*w);
                }
            }
        }
        result
    };

    for (color, tile) in start_tiles.into_iter().enumerate() {
        for tile in search(tile) {
            color_map.insert(tile, color as i32);
        }
    }

    color_map
}

fn map_coords_to_notation() -> HashMap<(i32, i32), (char, i32)> {
    let letters = "abcdefghijk".chars();

    let mapping = &DIRECTIONS.adjacent.mapping;

    let verticals = draw_line(mapping, (Hor::Right, Ver::Down), (-5, 2), None)
        .into_iter()
        .chain(draw_line(mapping, (Hor::Right, Ver::Up), (1, 4), None));

    verticals
        .zip(letters)
        .flat_map(|(coords, char)| {
            draw_line(mapping, (Hor::None, Ver::Up), coords, None)
                .iter()
                .enumerate()
                .map(|(i, coords)| (*coords, (char, (i as i32) + 1)))
                .collect::<HashMap<(i32, i32), (char, i32)>>()
        })
        .collect()
}

fn map_tile_pairs_to_directions() -> HashMap<((i32, i32), (i32, i32)), Line> {
    let mut res = HashMap::new();

    for tile_map in [&DIRECTIONS.bishop, &DIRECTIONS.adjacent] {
        for tile in BOARD_TILES.iter() {
            for dir in &tile_map.directions {
                let line = draw_line(&tile_map.mapping, *dir, *tile, None);

                for (distance, new_tile) in line.iter().enumerate() {
                    if distance == 0 {
                        continue;
                    }
                    res.insert(
                        (*tile, *new_tile),
                        Line {
                            len: distance,
                            tiles: line.clone().into_iter().take(distance).collect(),
                            dir: (tile_map.id, *dir),
                        },
                    );
                }
            }
        }
    }

    res
}
