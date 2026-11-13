import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

// The manifest supports pinned GitHub trees and optional whitespace-separated selections.
const selected = new Map();
for (const line of readFileSync(process.argv[2], 'utf8').split('\n')) {
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

// Match the pinned CLI's lock location, including its XDG override.
const lockPath = process.env.XDG_STATE_HOME
    ? join(process.env.XDG_STATE_HOME, 'skills', '.skill-lock.json')
    : join(homedir(), '.agents', '.skill-lock.json');
let lock;
try {
    lock = JSON.parse(readFileSync(lockPath, 'utf8'));
} catch (error) {
    if (error.code === 'ENOENT') process.exit(0);
    throw error;
}
for (const [name, entry] of Object.entries(lock.skills ?? {})) {
    if (typeof entry.source !== 'string') continue;
    const source = entry.source.toLowerCase();
    const names = selected.get(source);
    if (selected.has(source) && (names === null || names.has(name) || names.has('*'))) continue;
    // Keep shell invocation on Windows safe, and reject CLI wildcard/option syntax.
    if (!/^[a-zA-Z0-9][a-zA-Z0-9._-]*$/.test(name)) {
        throw new Error(`Unsupported locked skill name: ${name}`);
    }
    const result = spawnSync(process.platform === 'win32' ? 'npx.cmd' : 'npx', [
        '--yes', 'skills@1.7.6', 'remove', name, '--global', '--yes',
        '--agent', 'claude-code', 'codex',
    ], { encoding: 'utf8', shell: process.platform === 'win32' });
    if (result.error || result.status !== 0) {
        throw new Error(`Failed to remove ${name}: ${result.error ?? result.stdout + result.stderr}`);
    }
    console.log(`removed: ${name} (${entry.source})`);
}
