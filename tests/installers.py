import os
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
    for name in ('skills', 'global'):
        shutil.copytree(source_repo / name, repo / name)
    subprocess.run(['git', 'init', '-q', str(repo)], check=True)
    home = repo / '.scratch' / 'home'
    home.mkdir(parents=True)
    env = dict(os.environ, HOME=str(home), USERPROFILE=str(home),
               INSTALLER_TEST_HOME=str(home), DO_NOT_TRACK='1')

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
    manifest = repo / 'external-skills.txt'
    manifest.write_bytes(f'# comment\r\n\r\n{source.as_posix()} --skill alpha beta # selections\r\n'.encode())
    install('--external-skills')
    for name in ('alpha', 'beta'):
        for agent in ('.agents', '.claude'):
            assert (home / agent / 'skills' / name / 'reference.txt').read_text() == f'Synthetic {name} reference.\n'
    assert not (home / '.agents' / 'skills' / 'gamma').exists()

    manifest.write_text(source.as_posix())  # Whole repo, without a final newline.
    install('--external-skills')
    assert (home / '.agents' / 'skills' / 'gamma' / 'SKILL.md').is_file()

    next_entry = f'{source.as_posix()} --skill beta'
    manifest.write_text(f'{source.as_posix()} --skill alpha missing\n{next_entry}\n')
    output = install('--external-skills', expected=1)
    assert f'installing: {next_entry}' not in output

    # A pinned GitHub URL must keep installing the old commit after its branch moves.
    def git(*args):
        return subprocess.check_output(['git', '-C', str(source), *args], env=env,
                                       encoding='utf-8').strip()

    git('init', '-q')
    git('config', 'user.name', 'Fixture Author')
    git('config', 'user.email', 'fixture@example.invalid')
    git('add', '.')
    git('commit', '-qm', 'Initial synthetic skills')
    revision = git('rev-parse', 'HEAD')
    (source / 'alpha' / 'reference.txt').write_text('New branch content\n')
    git('commit', '-qam', 'Move the branch ahead of the pin')
    env['GIT_CONFIG_GLOBAL'] = str(repo / '.scratch' / 'gitconfig')
    remote = 'https://github.com/example/skills'
    git('config', '--global', f'url.{source.as_uri()}.insteadOf', remote + '.git')
    manifest.write_text(f'{remote}/tree/{revision} --skill alpha # ref=main\n')
    install('--external-skills')
    for agent in ('.agents', '.claude'):
        assert (home / agent / 'skills' / 'alpha' / 'reference.txt').read_text() == 'Synthetic alpha reference.\n'

    manifest.write_text(f'{remote}/tree/{"0" * 40} --skill alpha # ref=main\n')
    install('--external-skills', expected=1)
