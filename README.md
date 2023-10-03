# HexChess
HexChess is a hexagonal chess program powered with the Godot Engine. It includes several variants of hex chess (Glinski, McCooey, Hexofen), basic AI and peer-to-peer multiplayer.

To manipulate the source code you'll need Godot 3.5 .NET version. The code is licensed under the MIT license, feel free to use it in your projects. However, there are additional restrictions on some visual assets; check subdirectories for more info.

# Compilation
Starting from version 2.0, the app includes a portion of code written in Rust. If you want to compile it, refer to the Rust/Godot setup instructions [here](https://godot-rust.github.io/book/gdnative/intro/setup.html). 

As soon as you have your setup ready, open a project directory and start the compilation with '[cargo build](https://doc.rust-lang.org/cargo/commands/cargo-build.html)' command.

After the compilation is finished, move the resulting library file to the 'godot' subdirectory. For example, on Windows, when using an optimized build, use this command:

  `Move-Item "target/release/hex_chess.dll" -Destination "godot/hex_chess.dll"`

On Linux, use this command:

  `mv target/release/libhex_chess.so godot`

After moving the library, start the game normally via the Godot Engine. If you don't want to compile the Rust portion of the code and just want to modify the GDScript part of the project, you can use a precomiled library file from the latest [release](https://github.com/esbudylin/HexChess/releases) by placing it in the 'godot' subdirectory.

# Screenshots
## Local game against AI
 <img src="https://github.com/esbudylin/HexChess/assets/111509227/1a752643-764c-4202-ade2-9de20d5dcd43">

## Networked game
 <img src="https://github.com/esbudylin/HexChess/assets/111509227/cb116144-b204-4346-b6fe-c0e7ff44cc8b" >
