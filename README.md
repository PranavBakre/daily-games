# Daily Games

Four small puzzles a day — **Zip**, **Tango**, **Sudoku** and **Number Merge** — in plain HTML,
CSS and JavaScript. No framework, no build step, no accounts, no network calls.

- **Fresh puzzles forever.** Levels are generated on your device from a seeded
  random number generator. The daily set is pinned to the date, so it is the same
  puzzle all day; Practice generates a new one on demand.
- **Every board is solvable.** Zip, Tango and Sudoku check for a unique
  solution. Number Merge builds each board backwards from a finished tile,
  and you can solve it in more than one way.
- **Offline.** A service worker caches the shell on first load. After that the
  app opens with no connection at all — nothing is fetched to play.
- **Installable.** It is a valid PWA, so you can add it to your home screen on
  iOS or Android and it runs full screen.
- **Hints.** Each game has a Hint button. It points out a wrong cell if there is
  one; otherwise it fills a cell (Zip draws the next few steps). The win sheet
  shows how many hints you used.
- **Local progress.** Times, streaks and unfinished boards live in
  `localStorage`. Nothing leaves the browser.

## Play

Open the deployed site, or run it locally:

```sh
python3 -m http.server 4173
# then open http://localhost:4173
```

Service workers need `http://localhost` or HTTPS, so `file://` will not cache.
Everything still generates offline; only the PWA install and cache need a server.

## Tests

The generators are the part worth testing, so they are covered directly:

```sh
bun test
```

Each test builds puzzles and asserts the invariants: the solution is a legal
board, the hidden solution matches every clue, and a brute-force search finds
exactly one solution. Run time is well under a second.

## Deploy to GitHub Pages

The app is static and uses only relative URLs, so it works from a repository
subpath (`https://<user>.github.io/<repo>/`).

1. Push this repository to GitHub.
2. **Settings → Pages → Build and deployment → Deploy from a branch**.
3. Pick branch `main` and folder `/ (root)`, then save.

The included `.nojekyll` file keeps GitHub from running the pages through Jekyll.
After a deploy, load the site once so the service worker installs, then it works
offline.

If you change any cached file, bump `VERSION` in `sw.js` so returning visitors
pick up the new shell. (`index.html` is fetched network-first; the rest is
cache-first with a background refresh.)

## How the levels are made

**Zip** — a random [Hamiltonian path](https://en.wikipedia.org/wiki/Hamiltonian_path)
is walked over the grid with a most-constrained-neighbour heuristic, and cells
along it are numbered 1 … N, starting and ending on the path's ends. While a
solver still finds a second route, the generator adds a number where that route
breaks away (or, now and then, a wall across it). Clues the solution does not
need are then removed, so most boards read as numbers with a few walls at most.
The solver prunes dead-end cells and disconnected regions, and a test checks it
against brute force.

**Tango** — a full 6×6 board is filled by backtracking with row/column balance
and "no three in a row" pruning. Clues are then added: a handful of given cells
plus `=` / `×` edge badges, chosen one at a time until the search finds exactly
one solution. Redundant badges are removed afterwards so the board stays
readable.

**Sudoku** — the daily puzzle is a 6×6 Mini with 2×3 boxes; Practice also
offers 9×9 Easy, Medium and Hard.
A complete grid is built from the classic pattern and then
permuted (digits, bands, rows, stacks, columns). Cells are removed in random
order, one at a time, keeping a removal only when a bitmask solver with
minimum-remaining-values pruning still finds a single solution.

The same seed always produces the same puzzle, which is why the daily URL, a
reloaded practice board, and the tests all agree.

## Project layout

```
DESIGN.md             art direction: type, colour, layout rules
index.html            app shell
styles.css            all styling
js/app.js             routing, timer, daily/practice sessions, storage wiring
js/ui.js              tiny DOM helpers, icons, bottom sheets
js/rng.js             seeded PRNG (mulberry32) + seed hashing
js/storage.js         localStorage schema for results, streaks, saved boards
js/games/zip.js       Zip generator, solver and touch controller
js/games/tango.js     Tango generator, solver and controller
js/games/sudoku.js    Sudoku generator, solver and controller
sw.js                 offline cache
manifest.webmanifest  PWA metadata
icons/                generated PNG icons
tools/make-icons.mjs  dependency-free icon renderer
tests/                generator invariants
```

Each game module exports the same shape — `generate(seed, difficulty)`,
`create(container, options)` and a rules list — so the app shell does not know
anything about the puzzle internals.

## Notes

- Results are keyed by local date, so "today" follows the device clock.
- Streaks count consecutive days with a completed daily puzzle.
- Boards in progress are kept for the last 24 sessions.
- Private browsing usually clears `localStorage` when the tab closes.

MIT licensed.
