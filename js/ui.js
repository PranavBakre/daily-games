// Tiny DOM helpers. No framework, no build step.

export function h(tag, props, ...children) {
  const node = document.createElement(tag);
  if (props) {
    for (const [key, value] of Object.entries(props)) {
      if (value === null || value === undefined || value === false) continue;
      if (key === 'class') node.className = value;
      else if (key === 'text') node.textContent = value;
      else if (key === 'html') node.innerHTML = value;
      else if (key === 'style' && typeof value === 'object') {
        for (const [property, propertyValue] of Object.entries(value)) {
          node.style.setProperty(property, String(propertyValue));
        }
      }
      else if (key === 'dataset') Object.assign(node.dataset, value);
      else if (key.startsWith('on') && typeof value === 'function') {
        node.addEventListener(key.slice(2).toLowerCase(), value);
      } else if (key === 'value') node.value = value;
      else node.setAttribute(key, value === true ? '' : value);
    }
  }
  append(node, children);
  return node;
}

export function append(node, children) {
  for (const child of children.flat(Infinity)) {
    if (child === null || child === undefined || child === false) continue;
    node.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return node;
}

export function clear(node) {
  while (node.firstChild) node.removeChild(node.firstChild);
}

export function formatTime(ms) {
  const total = Math.max(0, Math.round(ms / 1000));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = total % 60;
  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
  }
  return `${minutes}:${String(seconds).padStart(2, '0')}`;
}

export function haptic(pattern = 8) {
  if (navigator.vibrate) {
    try {
      navigator.vibrate(pattern);
    } catch {
      /* ignore */
    }
  }
}

/** Modal sheet. Returns a function that closes it. */
export function openSheet(content, { dismissable = true } = {}) {
  const overlay = h('div', { class: 'sheet-backdrop', role: 'dialog', 'aria-modal': 'true' }, content);
  let closed = false;

  const close = () => {
    if (closed) return;
    closed = true;
    document.removeEventListener('keydown', onKey);
    overlay.classList.add('closing');
    setTimeout(() => overlay.remove(), 160);
  };

  function onKey(event) {
    if (event.key === 'Escape' && dismissable) close();
  }

  overlay.addEventListener('click', (event) => {
    if (event.target === overlay && dismissable) close();
  });
  document.addEventListener('keydown', onKey);
  document.body.append(overlay);
  requestAnimationFrame(() => overlay.classList.add('open'));
  overlay.querySelector('[data-autofocus]')?.focus();

  return close;
}

const ICONS = {
  zip: `<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="5" width="38" height="38" fill="#fff"/><path d="M17.7 5v38M30.3 5v38M5 17.7h38M5 30.3h38" stroke-width="1"/><path d="M11.3 36.7V24h12.7v-12.7h12.7v25.4" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" opacity=".9"/><circle cx="11.3" cy="36.7" r="4.6" fill="currentColor" stroke="none"/><circle cx="36.7" cy="36.7" r="4.6" fill="currentColor" stroke="none"/></svg>`,
  tango: `<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="5" width="38" height="38" fill="#fff"/><path d="M24 5v38M5 24h38" stroke-width="1"/><circle cx="14.5" cy="14.5" r="4" fill="currentColor" stroke="none"/><path d="M14.5 7.5v1.6M14.5 19.9v1.6M7.5 14.5h1.6M19.9 14.5h1.6" stroke-width="1.8" stroke-linecap="round"/><circle cx="33.5" cy="33.5" r="4" fill="currentColor" stroke="none"/><path d="M33.5 26.5v1.6M33.5 38.9v1.6M26.5 33.5h1.6M38.9 33.5h1.6" stroke-width="1.8" stroke-linecap="round"/><path d="M38.2 16.2a5.4 5.4 0 1 1-5.1-6.9 4.4 4.4 0 0 0 5.1 6.9Z" fill="currentColor" stroke="none"/><path d="M19.2 35.2a5.4 5.4 0 1 1-5.1-6.9 4.4 4.4 0 0 0 5.1 6.9Z" fill="currentColor" stroke="none"/></svg>`,
  sudoku: `<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="5" width="38" height="38" fill="#fff"/><path d="M17.7 5v38M30.3 5v38M5 17.7h38M5 30.3h38" stroke-width="1"/><g fill="currentColor" stroke="none" font-family="Georgia, serif" font-weight="700" font-size="10" text-anchor="middle"><text x="11.3" y="15">4</text><text x="36.7" y="15">1</text><text x="24" y="27.6">6</text><text x="11.3" y="40.2">2</text><text x="36.7" y="40.2">5</text></g></svg>`,
  back: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 5.5 8 12l6.5 6.5"/></svg>`,
  check: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 12.5 9.5 17.5 19.5 6.5"/></svg>`,
  install: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v10"/><path d="M8 10.5 12 14.5 16 10.5"/><path d="M5 17.5v1.5a1.5 1.5 0 0 0 1.5 1.5h11a1.5 1.5 0 0 0 1.5-1.5v-1.5"/></svg>`,
};

export function icon(name, className = 'icon') {
  const span = document.createElement('span');
  span.className = className;
  span.setAttribute('aria-hidden', 'true');
  if (name === 'merge') {
    span.classList.add('merge-icon');
    span.textContent = '2 + 2';
  } else {
    span.innerHTML = ICONS[name] ?? '';
  }
  return span;
}
