# Join the Dots

Join the Dots is a FireMonkey desktop version of the classic dots-and-boxes game.

Players take turns claiming lines between adjacent dots. When a player completes the fourth side of a square, they score that square and get another turn. The player with the most completed squares when the board is full wins.

## Features

- Two-player local play
- Optional AI opponent
- Small, medium, and large board sizes
- Square and hexagon board styles
- Player-colored lines and claimed squares
- Scoreboard and game-over result
- New game control

## Requirements

- Embarcadero RAD Studio with FireMonkey support
- Windows target configuration

The project was built as an FMX application and currently targets the RAD Studio project configuration stored in `JoinTheDots.dproj`.

## Running

1. Open `JoinTheDots.dproj` in RAD Studio.
2. Select the desired target platform and build configuration.
3. Build and run the project.

## Project Files

- `JoinTheDots.dpr` - application entry point
- `JoinTheDots.dproj` - RAD Studio project file
- `formJoinTheDots.pas` - FireMonkey form, drawing, input handling, and AI timer
- `uJoinTheDotsGame.pas` - board generation, game state, scoring, and AI move selection
- `formJoinTheDots.fmx` - main form resource
