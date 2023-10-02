use std::collections::{HashMap, HashSet};

use crate::{variant::VariantName, basics::Color, mapping::{DIRECTIONS, draw_line, Hor, Ver}};

pub fn initial_positions(name: &VariantName) -> Vec<Vec<(i32, i32)>> {
    match name {
        VariantName::Glinski => vec![
            vec![
                (0, -1),
                (1, -2),
                (2, -2),
                (3, -3),
                (4, -3),
                (-1, -2),
                (-2, -2),
                (-3, -3),
                (-4, -3),
                (0, 1),
                (1, 1),
                (2, 2),
                (3, 2),
                (4, 3),
                (-1, 1),
                (-2, 2),
                (-3, 2),
                (-4, 3),
            ],
            vec![(-2, -4), (2, -4), (-2, 4), (2, 4)],
            vec![(0, -5), (0, -4), (0, -3), (0, 3), (0, 4), (0, 5)],
            vec![(-3, -4), (3, -4), (-3, 3), (3, 3)],
            vec![(-1, -5), (-1, 4)],
            vec![(1, 4), (1, -5)],
        ],

        VariantName::Mccooey => vec![
            vec![
                (0, -2),
                (1, -3),
                (2, -3),
                (3, -4),
                (-1, -3),
                (-2, -3),
                (-3, -4),
                (0, 2),
                (1, 2),
                (2, 3),
                (3, 3),
                (-1, 2),
                (-2, 3),
                (-3, 3),
            ],
            vec![(-1, -4), (1, -4), (-1, 3), (1, 3)],
            vec![(0, -5), (0, -4), (0, -3), (0, 3), (0, 4), (0, 5)],
            vec![(-2, -4), (2, -4), (-2, 4), (2, 4)],
            vec![(-1, -5), (-1, 4)],
            vec![(1, 4), (1, -5)],
        ],

        VariantName::Hexofen => vec![
            vec![
                (-5, -3),
                (-3, -3),
                (-1, -3),
                (1, -3),
                (3, -3),
                (5, -3),
                (-4, -3),
                (-2, -3),
                (0, -3),
                (2, -3),
                (4, -3),
                (-5, 2),
                (-3, 2),
                (-1, 2),
                (1, 2),
                (3, 2),
                (5, 2),
                (-4, 3),
                (-2, 3),
                (0, 3),
                (2, 3),
                (4, 3),
            ],
            vec![(-3, 3), (-1, 3), (1, 3), (-1, -4), (1, -4), (3, -4)],
            vec![(3, 3), (-3, -4), (0, 4), (0, -4), (1, -5), (-1, 4)],
            vec![(-2, 4), (-2, -4), (2, 4), (2, -4)],
            vec![(-1, -5), (1, 4)],
            vec![(0, 5), (0, -5)],
        ],
    }
}

pub fn find_promotion_tiles(variant: VariantName) -> HashMap<Color, HashSet<(i32, i32)>> {
    let mut result = HashMap::new();

    let n_map = &DIRECTIONS.adjacent.mapping;
    let b_map = &DIRECTIONS.bishop.mapping;

    let mut white = HashSet::new();
    let mut black = HashSet::new();

    if variant != VariantName::Hexofen {
        black.extend(draw_line(n_map, (Hor::Right, Ver::Down), (-5, 2), None));
        black.extend(draw_line(n_map, (Hor::Right, Ver::Up), (1, 4), None));

        white.extend(draw_line(n_map, (Hor::Right, Ver::Up), (-5, -3), None));
        white.extend(draw_line(n_map, (Hor::Right, Ver::Down), (1, -5), None));
    } else {
        let promotion = |vert: Vec<(i32, i32)>| {
            return vert
                .iter()
                .flat_map(|tile| draw_line(b_map, (Hor::Right, Ver::None), *tile, None))
                .collect();
        };

        white = promotion(draw_line(n_map, (Hor::Right, Ver::Up), (-3, -4), None));
        black = promotion(draw_line(n_map, (Hor::Right, Ver::Down), (-3, 3), None));
    }

    result.insert(Color::White, white);
    result.insert(Color::Black, black);

    result
}
