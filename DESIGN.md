# Design

Direction: **newspaper puzzle page**. Chosen 2026-11-15 from three directions
(LinkedIn-faithful, newspaper, plainer dark). References: NYT Games, The New
Yorker puzzles and Apple News puzzles home screens, and LinkedIn's game, results
and streak screens, via Mobbin.

The colour, type and spacing values live as tokens at the top of `styles.css`.
Use a token; do not write a new hex, rgba or pixel value where one exists.

## Type

- **Serif** (`--serif`: New York on Apple devices, then Georgia) for the
  masthead, section titles, game names and the solve time.
- **Sans** (`--sans`: the system face) for labels, buttons, rules and
  metadata.
- No spaced-out capitals. A section is a serif title over a rule.

## Colour

- Paper background, white boards and cards, black ink for text, frames and
  primary buttons.
- Each game owns one flat colour, used three ways: `--accent` for the block
  behind its icon and the results page, `--accent-ink` for marks drawn in it
  (Zip's line, hinted digits), `--accent-wash` for filled cells.
- Grey (`--ink-2`) only for metadata: dates, counts, captions.
- No gradients, glows, blurs or decorative shadows.

## Layout

- Home: masthead and dateline, a rule, then one row per game: colour block with
  a drawing of its board, serif name, one line on the game, puzzle number and
  status, one solid **Play** button. Practice is a text link. Then this week.
- Game: back, serif name, number and level, timer. A folding **How to play**
  box above the board. Boards have a 2 px ink frame and 1 px grey lines.
- Results: the game's colour fills the screen; serif "Solved." and time, then
  played, streak and best, then the week.

## Controls

- Buttons are pills with a 1.5 px ink border; the primary one is solid ink.
- One primary action per screen.
