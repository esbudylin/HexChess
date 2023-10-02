pub mod basics;
pub mod movement;
pub mod board;
pub mod initial_positions;
pub mod mapping;
pub mod turn;
pub mod variant;
pub mod engine;
pub mod search;

use gdnative::prelude::{godot_init, InitHandle};

// Function that registers all exposed classes to Godot
fn init(handle: InitHandle) {
    handle.add_class::<engine::ChessEngine>();
}

// macros that create the entry-points of the dynamic library.
godot_init!(init);