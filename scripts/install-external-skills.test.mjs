import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { test } from 'node:test';
import { installExternalSkills, parseManifest } from './install-external-skills.mjs';

const scratch = resolve('.scratch/external-skills-validation');
mkdirSync(scratch, { recursive: true });

function fixture(t, manifestText, { xdg = false } = {}) {
  const root = mkdtempSync(join(scratch, 'test-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const home = join(root, 'home');
  const stateHome = xdg ? join(root, 'state') : undefined;
  const state = stateHome ? join(stateHome, 'skills') : join(home, '.agents');
  mkdirSync(state, { recursive: true });
  const manifest = join(root, 'external-skills.txt');
  writeFileSync(manifest, manifestText);
  const lockPath = join(state, '.skill-lock.json');
  const receiptPath = join(state, '.external-skills-install.json');
  const calls = [];
  const messages = [];
  const available = { 'example/tools': ['alpha', 'beta'], 'example/pack': ['gamma', 'delta'] };

  function putSkill(source, name, extra = {}) {
    const lock = JSON.parse(readFileSync(lockPath, 'utf8'));
    lock.skills[name] = { source, sourceType: 'github', ...extra };
    writeFileSync(lockPath, JSON.stringify(lock));
    const canonical = join(home, '.agents', 'skills', name);
    mkdirSync(canonical, { recursive: true });
    writeFileSync(join(canonical, 'SKILL.md'), `# ${name}\n`);
    const agentLink = join(home, '.claude', 'skills', name);
    mkdirSync(join(home, '.claude', 'skills'), { recursive: true });
    rmSync(agentLink, { recursive: true, force: true });
    symlinkSync(canonical, agentLink, 'junction');
  }

  writeFileSync(lockPath, JSON.stringify({ version: 3, skills: {} }));
  const options = {
    home, stateHome, manifest,
    log: (message) => messages.push(message),
    run: (args) => {
      calls.push(args);
      const source = args[3];
      const selected = args.slice(args.indexOf('--skill') + 1, args.indexOf('--global'));
      for (const name of selected.includes('*') ? available[source] : selected) putSkill(source, name);
      return { status: 0 };
    },
  };
  return { root, home, state, manifest, lockPath, receiptPath, calls, messages, available,
    putSkill, run: (overrides) => installExternalSkills({ ...options, ...overrides }) };
}

test('groups nonadjacent selections, deduplicates them, and lets a whole repo win', () => {
  const groups = parseManifest('# comment\r\n example/tools@alpha # inline\nexample/pack@gamma\nexample/tools@beta\nexample/tools@alpha\nexample/pack');
  assert.equal(groups.length, 2);
  assert.deepEqual([...groups[0].skills], ['alpha', 'beta']);
  assert.equal(groups[1].all, true);
  assert.throws(() => parseManifest('example/tools@alpha;echo'), /line 1/);
});

test('first install batches a repo, rerun skips it, and only a new selection is installed', (t) => {
  const f = fixture(t, 'example/tools@alpha\nexample/tools@beta');
  f.run();
  assert.equal(f.calls.length, 1);
  assert.deepEqual(f.calls[0], ['--yes', 'skills', 'add', 'example/tools', '--skill', 'alpha', 'beta',
    '--global', '--yes', '--agent', 'claude-code', 'codex']);
  f.run();
  assert.equal(f.calls.length, 1);
  writeFileSync(f.manifest, 'example/tools@alpha\nexample/tools@beta\nexample/tools@epsilon');
  f.run();
  assert.deepEqual(f.calls[1].slice(5, -5), ['epsilon']);
});

test('existing CLI installs can be skipped without a receipt, but wrong-source and pinned installs cannot', (t) => {
  const f = fixture(t, 'example/tools@alpha');
  f.putSkill('example/tools', 'alpha');
  f.run();
  assert.equal(f.calls.length, 0);
  f.putSkill('other/tools', 'alpha');
  f.run();
  assert.equal(f.calls.length, 1);
  f.putSkill('example/tools', 'alpha', { ref: 'v1' });
  f.run();
  assert.equal(f.calls.length, 2);
});

test('repairs a missing agent link and a broken canonical skill', (t) => {
  const f = fixture(t, 'example/tools@alpha');
  f.run();
  rmSync(join(f.home, '.claude', 'skills', 'alpha'));
  f.run();
  assert.equal(f.calls.length, 2);
  rmSync(join(f.home, '.agents', 'skills', 'alpha'), { recursive: true });
  f.run();
  assert.equal(f.calls.length, 3);
});

test('whole repos require a completed install; refresh discovers additions; rerun and repair use receipts', (t) => {
  const f = fixture(t, 'example/pack', { xdg: true });
  f.putSkill('example/pack', 'gamma');
  f.run();
  assert.equal(f.calls.length, 1, 'one preexisting skill does not mean the whole repo is installed');
  f.run();
  assert.equal(f.calls.length, 1);
  f.available['example/pack'].push('epsilon');
  f.run({ refresh: true });
  assert.equal(f.calls.length, 2);
  assert.deepEqual(JSON.parse(readFileSync(f.receiptPath)).repositories['example/pack'], ['gamma', 'delta', 'epsilon']);
  f.run();
  assert.equal(f.calls.length, 2);
  rmSync(join(f.home, '.claude', 'skills', 'delta'));
  f.run();
  assert.equal(f.calls.length, 3);
  writeFileSync(f.manifest, 'example/pack\nexample/pack@zeta');
  f.available['example/pack'].push('zeta');
  f.run();
  assert.equal(f.calls.length, 4, 'adding an explicit selection invalidates an incomplete receipt');
});

test('refresh reinstalls named skills; removed manifest entries leave installed files alone', (t) => {
  const f = fixture(t, 'example/tools@alpha');
  f.run();
  f.run({ refresh: true });
  assert.equal(f.calls.length, 2);
  writeFileSync(f.manifest, '# no packages\n');
  f.run();
  assert.match(readFileSync(join(f.home, '.agents', 'skills', 'alpha', 'SKILL.md'), 'utf8'), /alpha/);
});

test('failed or incomplete installs stop before later repositories and are retried', (t) => {
  const f = fixture(t, 'example/pack\nexample/tools@alpha');
  assert.throws(() => f.run({ run: () => ({ status: 7 }) }), /exit 7/);
  assert.throws(() => f.run({ run: () => ({ status: 0 }) }), /did not record/);
  assert.throws(() => f.run({ run: () => ({ error: new Error('npx missing') }) }), /npx missing/);
  f.run();
  assert.equal(f.calls.length, 2);
  writeFileSync(f.lockPath, '{broken');
  assert.throws(() => f.run({ run: () => ({ status: 0 }) }), /did not record/);
});

test('a successful CLI exit with a missing named skill is still an error', (t) => {
  const f = fixture(t, 'example/tools@alpha\nexample/tools@beta');
  assert.throws(() => f.run({ run: () => {
    f.putSkill('example/tools', 'alpha');
    return { status: 0 };
  } }), /did not install all requested skills/);
  f.run();
  assert.deepEqual(f.calls[0].slice(5, -5), ['beta']);
});

test('a corrupt receipt cannot hide a missing whole-repository install', (t) => {
  const f = fixture(t, 'example/pack');
  f.run();
  writeFileSync(f.receiptPath, '{broken');
  f.run();
  assert.equal(f.calls.length, 2);
  assert.deepEqual(JSON.parse(readFileSync(f.receiptPath)).repositories['example/pack'], ['gamma', 'delta']);
});
