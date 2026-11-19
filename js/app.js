import { h, formatTime, haptic, icon, openSheet } from './ui.js';
import { store, dateKey } from './storage.js';
import { randomSeed } from './rng.js';
import { zip } from './games/zip.js';
import { tango } from './games/tango.js';
import { sudoku } from './games/sudoku.js';

const GAMES = [zip, tango, sudoku];

const app = document.getElementById('app');

let session = null;
let installPrompt = null;

// ---------------------------------------------------------------- timer

function elapsed(s) {
  return s.elapsed + (s.runningSince ? Date.now() - s.runningSince : 0);
}

function resumeClock(s) {
  if (!s.runningSince && !s.solved) s.runningSince = Date.now();
}

function pauseClock(s) {
  if (s.runningSince) {
    s.elapsed += Date.now() - s.runningSince;
    s.runningSince = null;
  }
}

function paintTimer(s) {
  if (!s?.timerNode) return;
  s.timerNode.textContent = formatTime(elapsed(s));
}

// ---------------------------------------------------------------- routing

function parseRoute() {
  const raw = location.hash.replace(/^#\/?/, '');
  const [path, query = ''] = raw.split('?');
  const parts = path.split('/').filter(Boolean);
  const params = new URLSearchParams(query);
  const game = GAMES.find((candidate) => candidate.id === parts[0]);
  if (!game) return null;
  const mode = params.get('mode') === 'practice' ? 'practice' : 'daily';
  const difficulty = mode === 'practice'
    ? (params.get('d') || game.defaultDifficulty)
    : game.defaultDifficulty;
  return {
    game,
    mode,
    difficulty: game.difficulties.some((entry) => entry.id === difficulty) ? difficulty : game.defaultDifficulty,
    // Daily puzzles are pinned to the date so every device gets the same one;
    // practice puzzles carry their seed in the URL so a reload keeps the same board.
    seed: mode === 'daily' ? dateKey() : (params.get('seed') || randomSeed()),
  };
}

function route() {
  const target = parseRoute();
  if (target) openGame(target.game, target);
  else showHub();
}

window.addEventListener('hashchange', route);

function practiceHash(game, difficulty = game.defaultDifficulty, seed = randomSeed()) {
  return `#/${game.id}?mode=practice&d=${difficulty}&seed=${seed}`;
}

// ---------------------------------------------------------------- hub

const FIRST_DAY = new Date(2026, 10, 14);

function puzzleNumber(date = new Date()) {
  const day = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  return Math.max(1, Math.round((day - FIRST_DAY) / 86400000) + 1);
}

function liveStreak(game) {
  const streak = store.streak(game.id);
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  return streak.last === dateKey() || streak.last === dateKey(yesterday) ? streak.count : 0;
}

function statusLine(game) {
  const result = store.result(game.id, dateKey());
  const streak = liveStreak(game);
  const parts = [`No. ${puzzleNumber()} · ${labelForDifficulty(game, game.defaultDifficulty)}`];
  if (result) parts.push(formatTime(result.ms));
  if (streak > 1) parts.push(`${streak}-day streak`);
  return parts.join(' · ');
}

function gameCard(game) {
  const done = Boolean(store.result(game.id, dateKey()));
  const main = h(
    'button',
    {
      class: 'card-main',
      type: 'button',
      onclick: () => {
        haptic();
        location.hash = `#/${game.id}`;
      },
    },
    h('span', { class: 'game-tile' }, icon(game.icon)),
    h(
      'span',
      { class: 'game-text' },
      h('span', { class: 'game-name' }, game.name),
      h('span', { class: 'game-sub' }, game.tagline),
      h(
        'span',
        { class: 'game-row' },
        h('span', { class: 'game-status' }, statusLine(game)),
        done
          ? h('span', { class: 'play-pill done' }, icon('check', 'icon small'), 'Solved')
          : h('span', { class: 'play-pill' }, 'Play'),
      ),
    ),
  );

  const practice = h(
    'button',
    {
      class: 'practice-link',
      type: 'button',
      onclick: () => {
        haptic();
        location.hash = practiceHash(game);
      },
    },
    'Practice with a new puzzle',
  );

  return h('article', { class: `game-card accent-${game.id}` }, main, practice);
}

function solvedTodayCount() {
  return GAMES.reduce((total, game) => total + (store.solvedToday(game.id) ? 1 : 0), 0);
}

function renderInstallButton() {
  if (!installPrompt) return null;
  return h(
    'button',
    {
      class: 'btn install-btn',
      type: 'button',
      onclick: async () => {
        if (!installPrompt) return;
        installPrompt.prompt();
        await installPrompt.userChoice;
        installPrompt = null;
        showHub();
      },
    },
    icon('install', 'icon small'),
    'Install app',
  );
}

function lastSevenDays() {
  const days = [];
  for (let offset = 6; offset >= 0; offset--) {
    const date = new Date();
    date.setDate(date.getDate() - offset);
    days.push({ key: dateKey(date), date, today: offset === 0 });
  }
  return days;
}

function weekGrid(games) {
  return h(
    'div',
    { class: 'week-grid' },
    lastSevenDays().map(({ key, date, today }) =>
      h(
        'div',
        { class: `week-day${today ? ' today' : ''}` },
        h('span', { class: 'week-label' }, date.toLocaleDateString(undefined, { weekday: 'narrow' })),
        h(
          'div',
          { class: 'week-dots' },
          games.map((game) => h('span', {
            class: `week-dot accent-${game.id}${store.result(game.id, key) ? ' on' : ''}`,
            title: `${game.name}: ${store.result(game.id, key) ? 'solved' : 'not solved'}`,
          })),
        ),
      ),
    ),
  );
}

function showHub() {
  destroySession();
  const done = solvedTodayCount();
  const standalone = window.matchMedia?.('(display-mode: standalone)').matches
    || window.navigator.standalone === true;
  const isIos = /iphone|ipad|ipod/i.test(navigator.userAgent);
  const today = new Date().toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });

  const screen = h(
    'div',
    { class: 'screen hub' },
    h(
      'header',
      { class: 'hub-head' },
      h('h1', { class: 'masthead' }, 'Daily Games'),
      h('p', { class: 'dateline' }, `${today} · No. ${puzzleNumber()}`),
    ),
    h(
      'section',
      { class: 'cards', 'aria-label': "Today's puzzles" },
      h('h2', { class: 'section-title' }, done === GAMES.length ? 'All solved. Back tomorrow.' : "Today's puzzles"),
      GAMES.map(gameCard),
    ),
    h(
      'section',
      { class: 'week', 'aria-label': 'This week' },
      h('h2', { class: 'section-title' }, 'This week'),
      weekGrid(GAMES),
    ),
    h(
      'footer',
      { class: 'hub-foot' },
      h(
        'div',
        { class: 'hub-foot-row' },
        h('span', {}, `${done} of ${GAMES.length} solved today`),
        renderInstallButton(),
      ),
      !standalone && isIos
        ? h('p', { class: 'muted tiny' }, 'To install on iPhone, tap Share, then Add to Home Screen.')
        : null,
      h('p', { class: 'muted tiny' }, 'Works offline. Your progress stays on this device.'),
    ),
  );

  app.replaceChildren(screen);
  window.scrollTo({ top: 0 });
  document.title = 'Daily Games';
}

// ---------------------------------------------------------------- game screen

function difficultyChips(game, active) {
  return h(
    'div',
    { class: 'chips', role: 'group', 'aria-label': 'Difficulty' },
    game.difficulties.map((entry) =>
      h(
        'button',
        {
          class: `chip${entry.id === active ? ' active' : ''}`,
          type: 'button',
          'aria-pressed': String(entry.id === active),
          onclick: () => {
            haptic();
            location.hash = practiceHash(game, entry.id);
          },
        },
        entry.label,
      ),
    ),
  );
}

function modeSwitch(game, mode) {
  return h(
    'div',
    { class: 'segmented', role: 'group', 'aria-label': 'Mode' },
    ['daily', 'practice'].map((value) =>
      h(
        'button',
        {
          class: `segment${value === mode ? ' active' : ''}`,
          type: 'button',
          'aria-pressed': String(value === mode),
          onclick: () => {
            if (value === mode) return;
            haptic();
            location.hash = value === 'daily' ? `#/${game.id}` : practiceHash(game, session?.difficulty ?? game.defaultDifficulty);
          },
        },
        value === 'daily' ? 'Daily' : 'Practice',
      ),
    ),
  );
}

function openGame(game, { mode, difficulty, seed }) {
  destroySession();

  const key = mode === 'daily' ? dateKey() : String(seed);
  const saveId = `${game.id}:${mode}:${key}`;
  const saved = store.loadSession(saveId);
  const result = mode === 'daily' ? store.result(game.id, dateKey()) : null;

  const timerNode = h('div', { class: 'timer', text: '0:00' });
  const stage = h('div', { class: 'stage' }, h('div', { class: 'stage-loading' }, 'Generating a puzzle…'));

  const seenKey = `dg-howto-${game.id}`;
  const firstVisit = localStorage.getItem(seenKey) === null;
  try {
    localStorage.setItem(seenKey, '1');
  } catch {
    /* storage full or blocked */
  }
  const howTo = h(
    'details',
    { class: 'howto', open: firstVisit },
    h('summary', {}, 'How to play'),
    h('ol', {}, game.rules.map((rule) => h('li', {}, rule))),
  );

  const head = h(
    'header',
    { class: 'game-head' },
    h(
      'button',
      {
        class: 'icon-btn',
        type: 'button',
        'aria-label': 'Back to games',
        onclick: () => {
          haptic();
          location.hash = '';
        },
      },
      icon('back'),
    ),
    h(
      'div',
      { class: 'game-title' },
      h('h1', {}, game.name),
      h('span', { class: 'game-meta' }, `${mode === 'daily' ? `No. ${puzzleNumber()}` : 'Practice'} · ${labelForDifficulty(game, difficulty)}`),
    ),
    timerNode,
  );

  const screen = h(
    'div',
    { class: `screen game accent-${game.id}` },
    head,
    h('div', { class: 'game-subbar' }, modeSwitch(game, mode), mode === 'practice' ? difficultyChips(game, difficulty) : null),
    result
      ? h(
          'div',
          { class: 'solved-banner' },
          h('span', { class: 'solved-banner-icon' }, icon('check', 'icon small')),
          `Solved today in ${formatTime(result.ms)}. Playing again won't change your time.`,
        )
      : null,
    howTo,
    stage,
    mode === 'practice'
      ? h(
          'div',
          { class: 'game-foot' },
          h(
            'button',
            {
              class: 'btn primary',
              type: 'button',
              onclick: () => {
                haptic();
                location.hash = practiceHash(game, difficulty);
              },
            },
            'New puzzle',
          ),
        )
      : null,
  );

  app.replaceChildren(screen);
  window.scrollTo({ top: 0 });
  document.title = `${game.name} · Daily Games`;

  const state = {
    game,
    mode,
    difficulty,
    seed,
    key,
    saveId,
    timerNode,
    stage,
    elapsed: saved?.elapsed ?? 0,
    runningSince: null,
    solved: false,
    controller: null,
    ticker: null,
    saveTimer: null,
  };
  session = state;
  paintTimer(state);

  // Let the shell paint before the (synchronous) generator runs.
  requestAnimationFrame(() => setTimeout(() => {
    if (session !== state) return;
    mountGame(state);
  }, 0));
}

function labelForDifficulty(game, difficulty) {
  return game.difficulties.find((entry) => entry.id === difficulty)?.label ?? difficulty;
}

function mountGame(state) {
  const { game, stage, saveId, seed, difficulty, mode } = state;
  let puzzle;
  try {
    puzzle = game.generate(`${game.id}:${mode}:${seed}`, difficulty);
  } catch (error) {
    console.error(error);
    stage.replaceChildren(
      h(
        'div',
        { class: 'error-card' },
        h('p', {}, 'Could not generate a puzzle.'),
        h(
          'button',
          {
            class: 'btn primary',
            type: 'button',
            onclick: () => location.reload(),
          },
          'Try again',
        ),
      ),
    );
    return;
  }
  if (session !== state) return;

  const saved = store.loadSession(saveId);
  stage.replaceChildren();

  const queueSave = () => {
    if (state.saveTimer) clearTimeout(state.saveTimer);
    state.saveTimer = setTimeout(() => saveProgress(state), 220);
  };

  state.controller = game.create(stage, {
    puzzle,
    saved: saved?.data ?? null,
    difficulty,
    onChange: queueSave,
    onSolve: () => finish(state),
  });

  resumeClock(state);
  paintTimer(state);
  state.ticker = setInterval(() => paintTimer(state), 400);
  saveProgress(state);
}

function saveProgress(state) {
  if (!state?.controller || state.solved) return;
  store.saveSession(state.saveId, state.controller.getState(), elapsed(state));
}

function finish(state) {
  if (state.solved) return;
  state.solved = true;
  state.hints = state.controller?.getState().hints ?? 0;
  pauseClock(state);
  const ms = Math.max(1000, elapsed(state));
  paintTimer(state);

  const { game, mode, difficulty, key } = state;
  store.saveResult({ game: game.id, key, mode, difficulty, ms });
  store.clearSession(state.saveId);

  document.querySelector('.stage')?.classList.add('stage-solved');
  haptic([16, 60, 16]);
  showWinSheet(state, ms);
}

function showWinSheet(state, ms) {
  const { game, mode, difficulty } = state;
  const best = store.best(game.id, difficulty);
  const hints = state.hints ? ` · ${state.hints} hint${state.hints === 1 ? '' : 's'}` : '';

  const nextPractice = () => {
    close();
    location.hash = practiceHash(game, difficulty);
  };
  const backToGames = () => {
    close();
    location.hash = '';
  };

  const stat = (value, label) => h('div', { class: 'win-stat' }, h('strong', {}, value), h('span', {}, label));

  const sheet = h(
    'div',
    { class: `sheet win accent-${game.id}` },
    h('p', { class: 'win-kicker' }, `${game.name} · ${mode === 'daily' ? `No. ${puzzleNumber()}` : 'Practice'} · ${labelForDifficulty(game, difficulty)}${hints}`),
    h('h2', {}, 'Solved.'),
    h('p', { class: 'win-time' }, formatTime(ms)),
    h('p', { class: 'win-best' }, best === ms ? 'New personal best' : best ? `Your best: ${formatTime(best)}` : ''),
    h(
      'div',
      { class: 'win-stats' },
      stat(String(store.solvedCount(game.id)), 'Played'),
      stat(String(liveStreak(game)), 'Day streak'),
      stat(best ? formatTime(best) : '—', 'Best'),
    ),
    weekGrid([game]),
    h(
      'div',
      { class: 'sheet-actions' },
      mode === 'practice'
        ? h('button', { class: 'btn primary', type: 'button', 'data-autofocus': '', onclick: nextPractice }, 'New puzzle')
        : h('button', { class: 'btn primary', type: 'button', 'data-autofocus': '', onclick: backToGames }, 'Back to games'),
      mode === 'practice'
        ? h('button', { class: 'btn', type: 'button', onclick: backToGames }, 'Back to games')
        : h('button', { class: 'btn', type: 'button', onclick: nextPractice }, 'Practice another'),
    ),
  );

  const close = openSheet(sheet, { dismissable: false });
}

function destroySession() {
  if (!session) return;
  const state = session;
  session = null;
  clearInterval(state.ticker);
  if (state.saveTimer) clearTimeout(state.saveTimer);
  if (!state.solved) saveProgress(state);
  try {
    state.controller?.destroy();
  } catch (error) {
    console.warn('[app] cleanup failed', error);
  }
  state.controller = null;
}

// ---------------------------------------------------------------- lifecycle

document.addEventListener('visibilitychange', () => {
  if (!session) return;
  if (document.visibilityState === 'hidden') {
    pauseClock(session);
    saveProgress(session);
  } else {
    resumeClock(session);
    // A daily puzzle is pinned to its date; after midnight, start fresh.
    if (session.mode === 'daily' && session.key !== dateKey()) {
      location.hash = '';
      showHub();
    }
  }
});

window.addEventListener('pagehide', () => {
  if (session && !session.solved) saveProgress(session);
});

window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  installPrompt = event;
  if (!session) showHub();
});

window.addEventListener('appinstalled', () => {
  installPrompt = null;
  if (!session) showHub();
});

if ('serviceWorker' in navigator && location.protocol.startsWith('http')) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch((error) => console.warn('[sw]', error));
  });
}

try {
  const { merge } = await import('./games/merge.js');
  GAMES.push(merge);
} catch (error) {
  // A returning offline client may still have the old service worker cache.
  console.warn('[app] Number Merge is unavailable', error);
}

route();
