// Browser-local persistence. Nothing leaves the device.

const KEY = 'daily-games:v1';
const MAX_SAVED = 24;
const MAX_HISTORY = 200;

function emptyState() {
  return {
    results: {}, // results[game][key] = { ms, difficulty, at }
    best: {}, // best[game][difficulty] = ms
    streaks: {}, // streaks[game] = { count, last }
    saved: {}, // saved[sessionId] = { data, elapsed, at }
    history: [], // [{ game, key, mode, difficulty, ms, at }]
    prefs: {},
  };
}

function read() {
  try {
    const raw = window.localStorage.getItem(KEY);
    if (!raw) return emptyState();
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return emptyState();
    return { ...emptyState(), ...parsed };
  } catch {
    return emptyState();
  }
}

let state = read();
let writeTimer = null;

function persist() {
  try {
    window.localStorage.setItem(KEY, JSON.stringify(state));
  } catch (error) {
    console.warn('[storage] could not persist', error);
  }
}

function flush() {
  if (writeTimer !== null) {
    clearTimeout(writeTimer);
    writeTimer = null;
  }
  persist();
}

// localStorage writes are cheap but happen on every move, so batch them.
function schedulePersist() {
  if (writeTimer !== null) return;
  writeTimer = setTimeout(() => {
    writeTimer = null;
    persist();
  }, 250);
}

if (typeof window !== 'undefined') {
  window.addEventListener('pagehide', flush);
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') flush();
  });
}

export function dateKey(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function previousDateKey() {
  const date = new Date();
  date.setDate(date.getDate() - 1);
  return dateKey(date);
}

export const store = {
  result(game, key) {
    return state.results[game]?.[key] ?? null;
  },

  saveResult({ game, key, mode, difficulty, ms }) {
    if (!state.results[game]) state.results[game] = {};
    const previous = state.results[game][key];
    // Keep the fastest run for the day, but always record that it was solved.
    state.results[game][key] = {
      ms: previous ? Math.min(previous.ms, ms) : ms,
      difficulty,
      at: previous?.at ?? Date.now(),
    };

    if (mode === 'daily') {
      const streak = state.streaks[game] ?? { count: 0, last: null };
      if (streak.last !== key) {
        streak.count = streak.last === previousDateKey() ? streak.count + 1 : 1;
        streak.last = key;
      }
      state.streaks[game] = streak;

      state.history.unshift({ game, key, mode, difficulty, ms, at: Date.now() });
      state.history = state.history.slice(0, MAX_HISTORY);
    }

    if (!state.best[game]) state.best[game] = {};
    const best = state.best[game][difficulty];
    if (!best || ms < best) state.best[game][difficulty] = ms;

    schedulePersist();
  },

  best(game, difficulty) {
    return state.best[game]?.[difficulty] ?? null;
  },

  streak(game) {
    return state.streaks[game] ?? { count: 0, last: null };
  },

  solvedToday(game) {
    return Boolean(state.results[game]?.[dateKey()]);
  },

  solvedCount(game) {
    return Object.keys(state.results[game] ?? {}).length;
  },

  loadSession(id) {
    return state.saved[id] ?? null;
  },

  saveSession(id, data, elapsed) {
    state.saved[id] = { data, elapsed, at: Date.now() };
    const ids = Object.keys(state.saved);
    if (ids.length > MAX_SAVED) {
      ids.sort((a, b) => (state.saved[a].at ?? 0) - (state.saved[b].at ?? 0));
      for (const stale of ids.slice(0, ids.length - MAX_SAVED)) delete state.saved[stale];
    }
    schedulePersist();
  },

  clearSession(id) {
    delete state.saved[id];
    schedulePersist();
  },

  pref(name, fallback = null) {
    return state.prefs?.[name] ?? fallback;
  },

  setPref(name, value) {
    state.prefs = { ...state.prefs, [name]: value };
    schedulePersist();
  },
};

export function flushStorage() {
  flush();
}
