import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const source = readFileSync(new URL('../public/dashboard/dashboard.js', import.meta.url), 'utf8');
const navigation = source.slice(source.indexOf("let roomWorkspaceTab ="), source.indexOf('export async function refresh')).replace('export function navigateConsole', 'function navigateConsole');

function fixture() {
  const root = { dataset: { consoleView: 'overview' } };
  const heading = { textContent: '', focusCalls: 0, focus() { this.focusCalls++; } };
  let tab = 'rooms';
  const buttons = ['overview', 'rooms', 'services', 'events'].map(view => ({
    dataset: { consoleDestination: view },
    current: false,
    setAttribute() { this.current = true; },
    removeAttribute() { this.current = false; },
  }));
  const sections = ['overview', 'services', 'workspace'].map(section => ({ dataset: { consoleSection: section }, hidden: false }));
  const context = {
    document: {
      getElementById: (id: string) => id === 'dashboard-root' ? root : heading,
      querySelectorAll: (selector: string) => selector.includes('destination') ? buttons : sections,
      querySelector: () => ({ dataset: { workspaceTab: tab } }),
    },
    t: (value: string) => value,
    switchWorkspaceTab: (value: string) => { tab = value; },
  };
  const navigate = runInNewContext(`${navigation}; navigateConsole`, context) as (view: string) => void;
  return { navigate, root, heading, sections, buttons, selectChat: () => { tab = 'chat-rooms'; }, currentTab: () => tab };
}

test('console navigation exposes one destination and the corresponding content', () => {
  const state = fixture();
  for (const view of ['overview', 'rooms', 'services', 'events']) {
    state.navigate(view);
    assert.equal(state.root.dataset.consoleView, view);
    assert.equal(state.buttons.filter(button => button.current).length, 1);
    const section = state.sections.find(section => !section.hidden)!;
    assert.equal(section.dataset.consoleSection, ['rooms', 'events'].includes(view) ? 'workspace' : view);
  }
  assert.equal(state.heading.focusCalls, 4);
});

test('leaving rooms for events preserves the selected room type', () => {
  const state = fixture();
  state.navigate('rooms');
  state.selectChat();
  state.navigate('events');
  assert.equal(state.currentTab(), 'events');
  state.navigate('rooms');
  assert.equal(state.currentTab(), 'chat-rooms');
});

test('unknown destinations do not change the current view', () => {
  const state = fixture();
  state.navigate('unknown');
  assert.equal(state.root.dataset.consoleView, 'overview');
  assert.equal(state.heading.focusCalls, 0);
});
