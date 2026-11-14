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

export function formatDate(date = new Date()) {
  return date.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' });
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
  zip: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 20v-7.5A2.5 2.5 0 0 1 9.5 10h5A2.5 2.5 0 0 0 17 7.5V4"/><circle cx="7" cy="20" r="1.7" fill="currentColor" stroke="none"/><circle cx="17" cy="4" r="1.7" fill="currentColor" stroke="none"/></svg>`,
  tango: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="8.5" cy="8.5" r="3.2"/><path d="M8.5 3v1M8.5 13v1M3 8.5h1M13 8.5h1M4.6 4.6l.8.8M11.6 11.6l.8.8M12.4 4.6l-.8.8"/><path d="M21 15.5a5 5 0 1 1-4.6-6.3 5.6 5.6 0 0 0 4.6 6.3Z"/></svg>`,
  sudoku: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="3.5" y="3.5" width="17" height="17" rx="2.5"/><path d="M9.2 3.5v17M14.8 3.5v17M3.5 9.2h17M3.5 14.8h17"/></svg>`,
  back: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 5.5 8 12l6.5 6.5"/></svg>`,
  undo: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 8H5V5"/><path d="M5.2 8.2A8 8 0 1 1 4 13"/></svg>`,
  reset: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v5h5"/></svg>`,
  help: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M9.6 9.2a2.5 2.5 0 1 1 3.4 2.4c-.8.3-1 .9-1 1.7v.3"/><circle cx="12" cy="17" r=".9" fill="currentColor" stroke="none"/></svg>`,
  pencil: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20h4L19.5 8.5a2.1 2.1 0 0 0-3-3L5 17v3Z"/></svg>`,
  eraser: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 20h11"/><path d="M15.5 4.5 4.8 15.2a2.1 2.1 0 0 0 0 3l1.6 1.6a2.1 2.1 0 0 0 3 0L20 9.2a2.1 2.1 0 0 0 0-3l-1.6-1.7a2.1 2.1 0 0 0-3 0Z"/></svg>`,
  plus: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>`,
  flame: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12.6 2.2c.2 3-1.2 4.4-2.6 5.9C8.2 10 7 11.4 7 14a5 5 0 0 0 10 0c0-1.6-.6-2.8-1.4-4.1-.5.9-1.1 1.5-1.9 1.9.6-3.4-.4-7.2-1.1-9.6Z"/></svg>`,
  check: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 12.5 9.5 17.5 19.5 6.5"/></svg>`,
  install: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v10"/><path d="M8 10.5 12 14.5 16 10.5"/><path d="M5 17.5v1.5a1.5 1.5 0 0 0 1.5 1.5h11a1.5 1.5 0 0 0 1.5-1.5v-1.5"/></svg>`,
};

export function icon(name, className = 'icon') {
  const span = document.createElement('span');
  span.className = className;
  span.setAttribute('aria-hidden', 'true');
  span.innerHTML = ICONS[name] ?? '';
  return span;
}
