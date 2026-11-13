import os
import json
import re
from pathlib import Path
import subprocess
import shutil
import tempfile

source_repo = Path(__file__).resolve().parents[1]
# Keep new manifest entries from silently reintroducing moving source revisions.
for line in (source_repo / 'external-skills.txt').read_text().splitlines():
    entry = line.split('#', 1)[0].strip()
    if entry:
        assert re.fullmatch(r'https://github\.com/[^/]+/[^/]+/tree/[0-9a-f]{40}', entry.split()[0])

if subprocess.run(['git', 'check-ignore', '-q', '.scratch'], cwd=source_repo).returncode:
    exclude = subprocess.check_output(['git', 'rev-parse', '--git-path', 'info/exclude'],
                                      cwd=source_repo, text=True).strip()
    with (source_repo / exclude).open('a') as file:
        file.write('\n.scratch/\n')
scratch = source_repo / '.scratch'
scratch.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='installers-', dir=scratch) as temporary:
    repo = Path(temporary)
    for name in ('link.sh', 'link.ps1'):
        shutil.copy2(source_repo / name, repo / name)
    for name in ('skills', 'global', 'scripts', '.githooks'):
        shutil.copytree(source_repo / name, repo / name)
    subprocess.run(['git', 'init', '-q', str(repo)], check=True)
    home = repo / '.scratch' / 'home'
    home.mkdir(parents=True)
    cli_temporary = repo / '.scratch' / 'cli-tmp'
    cli_temporary.mkdir()
    env = dict(os.environ, HOME=str(home), USERPROFILE=str(home),
               INSTALLER_TEST_HOME=str(home), DO_NOT_TRACK='1', TMPDIR=str(cli_temporary),
               XDG_STATE_HOME=str(home / '.local' / 'state'),
               XDG_CONFIG_HOME=str(home / '.config'),
               GIT_CONFIG_GLOBAL=str(repo / '.scratch' / 'gitconfig'))

    def install(*flags, expected=0):
        if os.name == 'nt':
            switches = {'--global-instructions': '-GlobalInstructions',
                        '--external-skills': '-ExternalSkills'}
            script = 'Set-Variable HOME $env:INSTALLER_TEST_HOME -Force; & ./link.ps1 '
            command = ['pwsh', '-NoProfile', '-Command', script + ' '.join(switches[f] for f in flags)]
        else:
            command = ['/bin/bash', './link.sh', *flags]
        result = subprocess.run(command, cwd=repo, env=env, encoding='utf-8', stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=180)
        print(result.stdout)
        assert result.returncode == expected, f'Expected exit {expected}, got {result.returncode}'
        return result.stdout

    # Default installation and reruns keep both agents linked to this checkout.
    install()
    install()
    for skill in (repo / 'skills').iterdir():
        if skill.is_dir():
            for agent in ('.agents', '.claude'):
                assert (home / agent / 'skills' / skill.name).samefile(skill)

    # Preserve existing global instructions, then exercise linking absent files.
    instructions = [home / '.claude' / 'CLAUDE.md', home / '.codex' / 'AGENTS.md']
    for path in instructions:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('Synthetic existing instructions\n')
    install('--global-instructions')
    for path in instructions:
        assert path.read_text() == 'Synthetic existing instructions\n'
        path.unlink()
    install('--global-instructions')
    for path in instructions:
        assert path.samefile(repo / 'global' / 'AGENTS.md')

    # Use local skills to test the real CLI without fetching upstream skill repos.
    source = repo / '.scratch' / 'source'
    for name in ('alpha', 'beta', 'gamma'):
        skill = source / name
        skill.mkdir(parents=True)
        (skill / 'SKILL.md').write_text(f'---\nname: {name}\ndescription: Synthetic CI skill.\n---\n')
        (skill / 'reference.txt').write_text(f'Synthetic {name} reference.\n')
    def git(*args, directory=source):
        return subprocess.check_output(['git', '-C', str(directory), *args], env=env,
                                       encoding='utf-8').strip()

    def fixture_remote(directory, remote):
        git('init', '-q', directory=directory)
        git('config', 'user.name', 'Fixture Author', directory=directory)
        git('config', 'user.email', 'fixture@example.invalid', directory=directory)
        git('add', '.', directory=directory)
        git('commit', '-qm', 'Initial synthetic skills', directory=directory)
        revision = git('rev-parse', 'HEAD', directory=directory)
        git('config', '--global', f'url.{directory.as_uri()}.insteadOf', remote + '.git')
        return f'{remote}/tree/{revision}'

    remote = 'https://github.com/example/skills'
    pinned = fixture_remote(source, remote)
    second = repo / '.scratch' / 'second'
    second.mkdir()
    shutil.copytree(source / 'gamma', second / 'delta')
    (second / 'delta' / 'SKILL.md').write_text('---\nname: delta\ndescription: Synthetic CI skill.\n---\n')
    other = fixture_remote(second, 'https://github.com/example/other')
    handmade = home / '.agents' / 'skills' / 'handmade'
    handmade.mkdir()
    (handmade / 'SKILL.md').write_text('Synthetic handmade skill\n')

    # Another detected universal agent used to keep canonical copies and lock entries alive.
    (home / '.gemini').mkdir()
    manual = repo / '.scratch' / 'manual'
    manual.mkdir()
    shutil.copytree(source / 'gamma', manual / 'manual-skill')
    (manual / 'manual-skill' / 'SKILL.md').write_text('---\nname: manual-skill\ndescription: Synthetic manual skill.\n---\n')
    manual_pin = fixture_remote(manual, 'https://github.com/example/manual')
    for package in (manual_pin, f'{pinned} --skill gamma'):
        subprocess.run(['npx', '--yes', 'skills@1.7.6', 'add', *package.split(),
                        '--global', '--yes', '--json', '--agent', 'claude-code', 'codex'],
                       cwd=repo, env=env, check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       shell=os.name == 'nt')
    lock_path = Path(env['XDG_STATE_HOME']) / 'skills' / '.skill-lock.json'
    applied = repo / '.git' / 'external-skills.applied.txt'

    def lock_entries():
        return json.loads(lock_path.read_text())['skills']

    def add_locked(name, source):
        lock = json.loads(lock_path.read_text())
        lock['skills'][name] = dict(lock['skills']['manual-skill'], source=source)
        lock_path.write_text(json.dumps(lock))

    # Unrelated slash-containing names must never abort reconciliation.
    add_locked('design/anthropic-design-canvas', 'example/unlisted')
    manifest = repo / 'external-skills.txt'
    manifest.write_bytes(f'# comment\r\n\r\n{pinned} --skill alpha beta # selections\r\n{other}\r\n'.encode())
    assert 'removed:' not in install('--external-skills')
    assert applied.read_bytes() == manifest.read_bytes()
    assert (home / '.agents' / 'skills' / 'gamma' / 'SKILL.md').is_file()
    assert 'manual-skill' in lock_entries()
    assert 'design/anthropic-design-canvas' in lock_entries()
    for name in ('alpha', 'beta', 'delta'):
        for agent in ('.agents', '.claude'):
            assert (home / agent / 'skills' / name / 'SKILL.md').is_file()
    assert (home / '.agents' / 'skills' / 'gamma' / 'SKILL.md').is_file()

    # A removable name unsafe for CLI invocation warns and leaves the baseline for retry.
    add_locked('design/selected-canvas', 'example/other')
    previous = applied.read_bytes()
    # Dropping a source removes only its previously selected recorded skills.
    manifest.write_text(f'{pinned} --skill alpha beta\n')
    output = install('--external-skills')
    assert 'removed: delta (example/other)' in output
    assert 'warning: skipping unsupported locked skill name: design/selected-canvas' in output
    assert applied.read_bytes() == previous
    assert 'delta' not in lock_entries()
    lock = json.loads(lock_path.read_text())
    del lock['skills']['design/selected-canvas']  # Remove only this synthetic unsupported fixture.
    lock_path.write_text(json.dumps(lock))
    assert 'removed:' not in install('--external-skills')
    assert applied.read_bytes() == manifest.read_bytes()
    for agent in ('.agents', '.claude'):
        assert not (home / agent / 'skills' / 'delta').exists()
        assert (home / agent / 'skills' / 'beta' / 'SKILL.md').is_file()

    # Narrowing a selection prunes only the deselected skill; reruns are inert.
    manifest.write_text(f'{pinned} --skill alpha\n')
    output = install('--external-skills')
    assert 'removed: beta (example/skills)' in output
    assert 'beta' not in lock_entries()
    for agent in ('.agents', '.claude'):
        assert not (home / agent / 'skills' / 'beta').exists()
        assert (home / agent / 'skills' / 'alpha' / 'SKILL.md').is_file()
    assert 'removed:' not in install('--external-skills')
    assert (home / '.agents' / 'skills' / 'manual-skill' / 'SKILL.md').is_file()
    assert 'manual-skill' in lock_entries()
    assert 'design/anthropic-design-canvas' in lock_entries()
    assert (handmade / 'SKILL.md').read_text() == 'Synthetic handmade skill\n'
    for skill in (repo / 'skills').iterdir():
        for agent in ('.agents', '.claude'):
            assert (home / agent / 'skills' / skill.name).samefile(skill)

    manifest.write_text(pinned)  # Whole repo, without a final newline.
    install('--external-skills')
    assert (home / '.agents' / 'skills' / 'gamma' / 'SKILL.md').is_file()

    next_entry = f'{pinned} --skill beta'
    manifest.write_text(f'{pinned} --skill alpha missing\n{next_entry}\n')
    previous = applied.read_bytes()
    output = install('--external-skills', expected=1)
    assert applied.read_bytes() == previous
    assert f'installing: {next_entry}' not in output
    assert (home / '.agents' / 'skills' / 'gamma' / 'SKILL.md').is_file()

    # A pinned GitHub URL must keep installing the old commit after its branch moves.
    (source / 'alpha' / 'reference.txt').write_text('New branch content\n')
    git('commit', '-qam', 'Move the branch ahead of the pin')
    manifest.write_text(f'{pinned} --skill alpha # ref=main\n')
    install('--external-skills')
    for agent in ('.agents', '.claude'):
        assert (home / agent / 'skills' / 'alpha' / 'reference.txt').read_text() == 'Synthetic alpha reference.\n'

    manifest.write_text(f'{remote}/tree/{"0" * 40} --skill alpha # ref=main\n')
    previous = applied.read_bytes()
    install('--external-skills', expected=1)
    assert applied.read_bytes() == previous

    # Exercise the unattended post-merge path in a main checkout after a real pull.
    if os.name != 'nt':
        manifest.write_text(f'{pinned} --skill alpha beta\n{other}\n')
        git('branch', '-M', 'main', directory=repo)
        git('config', 'user.name', 'Fixture Author', directory=repo)
        git('config', 'user.email', 'fixture@example.invalid', directory=repo)
        git('add', 'link.sh', 'link.ps1', 'scripts', 'skills', 'global', '.githooks',
            'external-skills.txt', directory=repo)
        git('commit', '-qm', 'Initial installer fixture', directory=repo)
        checkout = repo / '.scratch' / 'hook-checkout'
        subprocess.run(['git', 'clone', '-q', str(repo), str(checkout)], env=env, check=True)
        subprocess.run(['bash', './link.sh', '--external-skills'], cwd=checkout, env=env,
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        hook_applied = checkout / '.git' / 'external-skills.applied.txt'
        hook_previous = hook_applied.read_bytes()
        manifest.write_text(f'{pinned} --skill alpha\n{remote}/tree/{"0" * 40} --skill alpha\n')
        git('add', 'external-skills.txt', directory=repo)
        git('commit', '-qm', 'Simulate a failing hook install', directory=repo)
        subprocess.run(['git', 'pull', '--ff-only'], cwd=checkout, env=env, check=True)
        assert hook_applied.read_bytes() == hook_previous
        assert 'beta' in lock_entries() and 'delta' in lock_entries()
        manifest.write_text(f'{pinned} --skill alpha\n')
        git('add', 'external-skills.txt', directory=repo)
        git('commit', '-qm', 'Drop source and narrow selection', directory=repo)
        subprocess.run(['git', 'pull', '--ff-only'], cwd=checkout, env=env, check=True)
        for agent in ('.agents', '.claude'):
            assert (home / agent / 'skills' / 'alpha' / 'SKILL.md').is_file()
            for name in ('beta', 'delta'):
                assert not (home / agent / 'skills' / name).exists()
            for skill in (checkout / 'skills').iterdir():
                assert (home / agent / 'skills' / skill.name).samefile(skill)
        assert (handmade / 'SKILL.md').is_file()
        print('Hook pull on main removed beta/delta and preserved alpha, handmade, and personal links.')
