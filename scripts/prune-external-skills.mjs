import { readFileSync, writeFileSync, renameSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';

// The manifest supports pinned GitHub trees and optional whitespace-separated selections.
function selections(manifest) {
    const selected = new Map();
    for (const line of manifest.split('\n')) {
        const args = line.split('#', 1)[0].trim().split(/\s+/);
        if (!args[0]) continue;
        const match = args[0].match(/^https:\/\/github\.com\/([^/]+\/[^/]+)\/tree\/[0-9a-f]{40}$/);
        if (!match || (args.length > 1 && (args[1] !== '--skill' || args.length < 3))) {
            throw new Error(`Unsupported manifest entry: ${line}`);
        }
        const source = match[1].toLowerCase();
        const names = args.length === 1 ? null : new Set(args.slice(2));
        if (!selected.has(source)) selected.set(source, names);
        else if (names === null) selected.set(source, null);
        else if (selected.get(source) !== null) {
            for (const name of names) selected.get(source).add(name);
        }
    }
    return (source, name) => selected.has(source) &&
        (selected.get(source) === null || selected.get(source).has(name) || selected.get(source).has('*'));
}

function readIfPresent(path, fallback) {
    try {
        return readFileSync(path, 'utf8');
    } catch (error) {
        if (error.code === 'ENOENT') return fallback;
        throw error;
    }
}

const manifest = readFileSync(process.argv[2], 'utf8');
const currentSelects = selections(manifest);
const gitDir = execFileSync('git', ['-C', dirname(process.argv[2]), 'rev-parse', '--absolute-git-dir'],
    { encoding: 'utf8' }).trim();
// Per-checkout state survives failed hooks and later pulls, unlike ORIG_HEAD.
const appliedPath = join(gitDir, 'external-skills.applied.txt');
const previousSelects = selections(readIfPresent(appliedPath, ''));

// Match the pinned CLI's lock location, including its XDG override.
const lockPath = process.env.XDG_STATE_HOME
    ? join(process.env.XDG_STATE_HOME, 'skills', '.skill-lock.json')
    : join(homedir(), '.agents', '.skill-lock.json');
const readLock = () => JSON.parse(readIfPresent(lockPath, '{"skills":{}}')).skills ?? {};
let skipped = false;
for (const [name, entry] of Object.entries(readLock())) {
    if (typeof entry?.source !== 'string') continue;
    const source = entry.source.toLowerCase();
    if (!previousSelects(source, name) || currentSelects(source, name)) continue;
    // Keep Windows shell invocation safe and reject CLI wildcard/option syntax.
    if (!/^[a-zA-Z0-9][a-zA-Z0-9._-]*$/.test(name)) {
        console.warn(`warning: skipping unsupported locked skill name: ${name}`);
        skipped = true;
        continue;
    }
    // Remove for all agents: several agents share the canonical directory with Codex.
    const result = spawnSync(process.platform === 'win32' ? 'npx.cmd' : 'npx', [
        '--yes', 'skills@1.7.6', 'remove', name, '--global', '--yes',
    ], { encoding: 'utf8', shell: process.platform === 'win32' });
    if (result.error || result.status !== 0) {
        throw new Error(`Failed to remove ${name}: ${result.error ?? result.stdout + result.stderr}`);
    }
    if (Object.hasOwn(readLock(), name)) {
        throw new Error(`Failed to remove ${name}: lock entry remains`);
    }
    console.log(`removed: ${name} (${entry.source})`);
}
// Do not advance the baseline after a failed or skipped removal; a later run retries it.
if (!skipped) {
    writeFileSync(`${appliedPath}.tmp`, manifest);
    renameSync(`${appliedPath}.tmp`, appliedPath);
}
