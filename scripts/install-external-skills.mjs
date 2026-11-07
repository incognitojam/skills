import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, realpathSync, statSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

function readJson(path) {
  try {
    const value = JSON.parse(readFileSync(path, 'utf8'));
    return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
  } catch (error) {
    if (error.code === 'ENOENT' || error instanceof SyntaxError) return {};
    throw error;
  }
}

export function parseManifest(text) {
  const repositories = new Map();
  for (const [index, line] of text.split(/\r?\n/).entries()) {
    const spec = line.replace(/#.*$/, '').trim();
    if (!spec) continue;
    // The manifest accepts GitHub owner/repo[@skill] shorthand, not shell input.
    const match = /^([\w.-]+\/[\w.-]+)(?:@([\w.-]+))?$/.exec(spec);
    if (!match) throw new Error(`Invalid package on external-skills.txt line ${index + 1}: ${spec}`);
    const [, source, skill] = match;
    const key = source.toLowerCase();
    const group = repositories.get(key) ?? { source, all: false, skills: new Set() };
    if (skill) group.skills.add(skill);
    else group.all = true;
    repositories.set(key, group);
  }
  return [...repositories.values()];
}

export function installExternalSkills({
  manifest,
  refresh = false,
  home = homedir(),
  stateHome = process.env.XDG_STATE_HOME,
  run = (args) => spawnSync(process.platform === 'win32' ? 'npx.cmd' : 'npx', args, {
    stdio: 'inherit',
    // Windows needs a shell for .cmd; every variable argument is validated above.
    shell: process.platform === 'win32',
  }),
  log = console.log,
}) {
  const repositories = parseManifest(readFileSync(manifest, 'utf8'));
  const lockPath = stateHome
    ? join(stateHome, 'skills', '.skill-lock.json')
    : join(home, '.agents', '.skill-lock.json');
  // Only whole-repository installs need a receipt: a lock entry alone cannot tell
  // us whether all of a repository's skills were installed or just one of them.
  const receiptPath = join(dirname(lockPath), '.external-skills-install.json');
  const saved = readJson(receiptPath);
  const receipts = saved.version === 1 && saved.repositories &&
    typeof saved.repositories === 'object' && !Array.isArray(saved.repositories) ? saved.repositories : {};

  function readLock() {
    const lock = readJson(lockPath);
    return lock.version >= 3 ? lock.skills ?? {} : {};
  }

  function installed(lock, source, name) {
    if (typeof name !== 'string' || !/^[\w.-]+$/.test(name) || name === '.' || name === '..') return false;
    const entry = lock[name];
    if (entry?.sourceType !== 'github' || typeof entry.source !== 'string' ||
      entry.source.toLowerCase() !== source.toLowerCase() || entry.ref) return false;
    return ['.agents', '.claude'].every((agent) => {
      const path = join(home, agent, 'skills', name, 'SKILL.md');
      return existsSync(path) && statSync(path).isFile();
    });
  }

  for (const { source, all, skills } of repositories) {
    const key = source.toLowerCase();
    const lock = readLock();
    const receipt = receipts[key];
    const complete = [...skills].every((name) => installed(lock, source, name)) && (!all ||
      Array.isArray(receipt) && receipt.length > 0 && receipt.every((name) => installed(lock, source, name)));
    if (!refresh && complete) {
      log(`skipped: ${source} (already installed)`);
      continue;
    }

    const selected = all ? ['*'] : [...skills].filter((name) => refresh || !installed(lock, source, name));
    // A missing member of a whole-repository receipt triggers a complete repair.
    const args = ['--yes', 'skills', 'add', source, '--skill', ...selected,
      '--global', '--yes', '--agent', 'claude-code', 'codex'];
    log(`installing: ${source} (${selected.join(', ')})`);
    const result = run(args);
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error(`Failed to install ${source} (exit ${result.status ?? result.signal}).`);

    const updated = readLock();
    if (![...skills].every((name) => installed(updated, source, name))) {
      throw new Error(`Installation of ${source} did not install all requested skills for both agents.`);
    }
    if (all) {
      const names = Object.keys(updated).filter((name) => installed(updated, source, name));
      if (!names.length) throw new Error(`Installation of ${source} did not record any installed skills.`);
      receipts[key] = names;
      mkdirSync(dirname(receiptPath), { recursive: true });
      writeFileSync(receiptPath, JSON.stringify({ version: 1, repositories: receipts }, null, 2) + '\n');
    }
  }
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2);
    if (args.length > 1 || (args.length === 1 && args[0] !== '--refresh')) {
      throw new Error('Usage: node scripts/install-external-skills.mjs [--refresh]');
    }
    installExternalSkills({
      manifest: fileURLToPath(new URL('../external-skills.txt', import.meta.url)),
      refresh: args[0] === '--refresh',
    });
  } catch (error) {
    console.error(`error: ${error.message}`);
    process.exitCode = 1;
  }
}
