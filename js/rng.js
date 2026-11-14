// Deterministic pseudo-random numbers.
//
// Every puzzle is generated on the device from a seed string, so there are no
// puzzle files to download and the same date always produces the same puzzle.

export function hashSeed(text) {
  let h = 2166136261 >>> 0;
  const s = String(text);
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  h ^= h >>> 16;
  h = Math.imul(h, 2246822507);
  h ^= h >>> 13;
  h = Math.imul(h, 3266489909);
  h ^= h >>> 16;
  return h >>> 0;
}

export class Rng {
  constructor(seed) {
    const value = typeof seed === 'number' ? seed >>> 0 : hashSeed(seed);
    this.state = value || 0x9e3779b9;
  }

  /** Float in [0, 1). */
  next() {
    this.state = (this.state + 0x6d2b79f5) | 0;
    let t = this.state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  int(n) {
    return Math.floor(this.next() * n);
  }

  chance(probability) {
    return this.next() < probability;
  }

  pick(list) {
    return list[this.int(list.length)];
  }

  /** In-place Fisher-Yates. */
  shuffle(list) {
    for (let i = list.length - 1; i > 0; i--) {
      const j = this.int(i + 1);
      const tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return list;
  }
}

export function randomSeed() {
  return Math.random().toString(36).slice(2, 8) + Date.now().toString(36).slice(-3);
}
