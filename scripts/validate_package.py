#!/usr/bin/env python3
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PAK = ROOT / 'dist' / 'StandPrototype.pak'


def wine_path(path: Path) -> str:
    return 'Z:' + str(path.resolve()).replace('/', '\\')


def run_list_package(pak: Path) -> tuple[int, str]:
    divine = os.environ.get('DIVINE_BIN')
    commands = []
    if divine:
        commands.append([divine, '-a', 'list-package', '-g', 'bg3', '-s', str(pak.resolve())])
    commands.append(['divine', '-a', 'list-package', '-g', 'bg3', '-s', str(pak.resolve())])

    legacy_exe = Path.home() / '.local/share/lslib-tools/v1.19.3/Tools/Divine.exe'
    if legacy_exe.exists():
        env = os.environ.copy()
        env.setdefault('WINEPREFIX', str(Path.home() / '.wine-divine'))
        env.setdefault('WINEDEBUG', '-all')
        commands.append([
            'wine',
            str(legacy_exe),
            '-a',
            'list-package',
            '-g',
            'bg3',
            '-s',
            wine_path(pak),
        ])

    last_output = ''
    for cmd in commands:
        try:
            env = os.environ.copy()
            if cmd[0] == 'wine':
                env.setdefault('WINEPREFIX', str(Path.home() / '.wine-divine'))
                env.setdefault('WINEDEBUG', '-all')
            result = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
        except FileNotFoundError as exc:
            last_output = str(exc)
            continue
        last_output = result.stdout
        if result.returncode == 0 and result.stdout.strip():
            return 0, result.stdout
    return 1, last_output


def run_legacy_divine(args: list[str]) -> tuple[int, str]:
    legacy_exe = Path.home() / '.local/share/lslib-tools/v1.19.3/Tools/Divine.exe'
    if not legacy_exe.exists():
        return 1, f'Legacy Divine not found: {legacy_exe}'
    env = os.environ.copy()
    env.setdefault('WINEPREFIX', str(Path.home() / '.wine-divine'))
    env.setdefault('WINEDEBUG', '-all')
    result = subprocess.run(
        ['wine', str(legacy_exe), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=env,
    )
    return result.returncode, result.stdout


def extract_package(pak: Path, dest: Path) -> tuple[int, str]:
    return run_legacy_divine([
        '-a', 'extract-package',
        '-g', 'bg3',
        '-s', wine_path(pak),
        '-d', wine_path(dest),
    ])


def convert_lsf_to_lsx(src: Path, dest: Path) -> tuple[int, str]:
    return run_legacy_divine([
        '-a', 'convert-resource',
        '-g', 'bg3',
        '-s', wine_path(src),
        '-d', wine_path(dest),
        '-i', 'lsf',
        '-o', 'lsx',
    ])


def read_text(path: Path) -> str:
    if not path.exists():
        return ''
    return path.read_text(encoding='utf-8-sig', errors='replace')


def main() -> int:
    parser = argparse.ArgumentParser(description='Validate packaged StandPrototype .pak contents.')
    parser.add_argument('--pak', default=str(DEFAULT_PAK), help='Path to StandPrototype.pak')
    args = parser.parse_args()

    pak = Path(args.pak)
    checks: list[tuple[str, bool, str]] = []

    def ok(name: str, condition: bool, detail: str = '') -> None:
        checks.append((name, bool(condition), detail))

    ok('Package file exists', pak.exists(), str(pak))
    ok('Package file is non-empty', pak.exists() and pak.stat().st_size > 64, str(pak))

    listing = ''
    if pak.exists():
        rc, listing = run_list_package(pak)
        ok('Package listing succeeds', rc == 0, listing[-500:] if rc != 0 else '')

    entries = set()
    for line in listing.splitlines():
        if not line.strip():
            continue
        entries.add(line.split('\t', 1)[0].strip().replace('\\', '/'))

    required_entries = [
        'Mods/StandPrototype/meta.lsx',
        'Mods/StandPrototype/ScriptExtender/Config.json',
        'Mods/StandPrototype/ScriptExtender/Lua/BootstrapServer.lua',
        'Mods/StandPrototype/ScriptExtender/Lua/StandFramework/StandDefinitions.lua',
        'Mods/StandPrototype/ScriptExtender/Lua/StandFramework/StandSystem.lua',
        'Mods/StandPrototype/ScriptExtender/Lua/StandFramework/SpellHandlers.lua',
        'Public/StandPrototype/RootTemplates/_merged.lsf',
        'Public/StandPrototype/Stats/Generated/Data/Character.txt',
        'Public/StandPrototype/Stats/Generated/Data/StandPrototype_Spells.txt',
        'Public/StandPrototype/Stats/Generated/Data/StandPrototype_Passives.txt',
        'Public/StandPrototype/Stats/Generated/Data/StandPrototype_Statuses.txt',
        'Public/StandPrototype/Stats/Generated/Equipment.txt',
        'Public/StandPrototype/ClassDescriptions/ClassDescriptions.lsx',
        'Public/StandPrototype/Progressions/Progressions.lsx',
        'Public/StandPrototype/Lists/SpellLists.lsx',
        'Localization/English/StandPrototype.loca',
    ]
    for entry in required_entries:
        ok(f'Package contains {entry}', entry in entries)

    root_template_lsx_entries = sorted(
        entry for entry in entries
        if entry.startswith('Public/StandPrototype/RootTemplates/') and entry.endswith('.lsx')
    )
    ok('Package does not contain loose RootTemplates .lsx files',
       not root_template_lsx_entries,
       ', '.join(root_template_lsx_entries))

    extract_dir = Path(tempfile.mkdtemp(prefix='standprototype_pkg_'))
    try:
        if pak.exists():
            rc, output = extract_package(pak, extract_dir)
            ok('Package extraction succeeds', rc == 0, output[-500:] if rc != 0 else str(extract_dir))

            character_txt = read_text(extract_dir / 'Public/StandPrototype/Stats/Generated/Data/Character.txt')
            spell_txt = read_text(extract_dir / 'Public/StandPrototype/Stats/Generated/Data/StandPrototype_Spells.txt')
            system_lua = read_text(extract_dir / 'Mods/StandPrototype/ScriptExtender/Lua/StandFramework/StandSystem.lua')
            defs_lua = read_text(extract_dir / 'Mods/StandPrototype/ScriptExtender/Lua/StandFramework/StandDefinitions.lua')

            ok('Packaged Character.txt contains concrete Stand stat entries',
               'new entry "STAND_BASE_BODY"' in character_txt
               and all(f'new entry "STAND_STAR_PLATINUM_BODY_L{tier}"' in character_txt for tier in [3, 5, 6, 10, 12]))
            ok('Packaged BaseStand stat owns generic actions through DefaultBoosts',
               'new entry "STAND_BASE_BODY"' in character_txt
               and 'UnlockSpell(Target_UnarmedAttack)' in character_txt
               and 'UnlockSpell(Target_Stand_BasicStrike)' in character_txt
               and 'UnlockSpell(Target_Stand_BasicBarrage)' in character_txt
               and 'UnlockSpell(Shout_Stand_BasicGuard)' in character_txt)
            star_tier_actions = {
                3: ['Target_UnarmedAttack', 'Target_Stand_Barrage', 'Shout_Stand_Intercept'],
                5: ['Target_UnarmedAttack', 'Target_Stand_Barrage', 'Shout_Stand_Intercept', 'Target_Stand_StarFinger'],
                6: ['Target_UnarmedAttack', 'Target_Stand_Barrage', 'Shout_Stand_Intercept', 'Target_Stand_StarFinger', 'Target_Stand_Rush'],
                10: ['Target_UnarmedAttack', 'Target_Stand_Barrage', 'Shout_Stand_Intercept', 'Target_Stand_StarFinger', 'Target_Stand_Rush', 'Target_Stand_RelentlessBarrage'],
                12: ['Target_UnarmedAttack', 'Target_Stand_Barrage', 'Shout_Stand_Intercept', 'Target_Stand_StarFinger', 'Target_Stand_Rush', 'Target_Stand_RelentlessBarrage', 'Shout_Stand_TimeStop'],
            }
            ok('Packaged Star Platinum tier stats own tier actions through DefaultBoosts',
               all(
                   f'new entry "STAND_STAR_PLATINUM_BODY_L{tier}"' in character_txt
                   and all(f'UnlockSpell({spell})' in character_txt.split(f'new entry "STAND_STAR_PLATINUM_BODY_L{tier}"', 1)[1].split('\nnew entry "', 1)[0] for spell in actions)
                   for tier, actions in star_tier_actions.items()
               ))
            ok('Packaged custom Stand SpellData entries exist',
               all(f'new entry "{spell}"' in spell_txt for spell in [
                   'Target_Stand_BasicStrike',
                   'Target_Stand_BasicBarrage',
                   'Shout_Stand_BasicGuard',
                   'Target_Stand_Barrage',
                   'Shout_Stand_Intercept',
                   'Target_Stand_StarFinger',
                   'Target_Stand_Rush',
                   'Target_Stand_RelentlessBarrage',
                   'Shout_Stand_TimeStop',
               ]))
            ok('Packaged runtime does not AddSpell or RemoveSpell Stand actions',
               'Osi.AddSpell' not in system_lua
               and 'Osi.RemoveSpell' not in system_lua
               and 'repairStandActionSpellbook' not in system_lua
               and 'enforceUserCommandOnlySpellbook' not in system_lua)
            ok('Packaged manifest creates temporary Stand characters',
               'pcall(Osi.CreateAt, template, sx, y, sz, 1, 0, "")' in system_lua
               and 'pcall(Osi.CreateAtObject, template, user, 1, 0, "", 1)' in system_lua)
            ok('Packaged withdraw uses temporary delete, not death cleanup',
               'requestDeleteTemporaryStand(user, stand, "withdraw")' in system_lua
               and 'Osi.RequestDeleteTemporary temporary-delete stand=' in system_lua
               and 'clearStandOwnershipAfterDelete(user, stand, "withdraw")' in system_lua
               and 'Osi.Die' not in system_lua
               and 'finalizeDeadStandEntity' not in system_lua
               and 'killStandEntityForWithdraw' not in system_lua
               and 'queueStandDespawn' not in system_lua
               and 'Osi.RequestDelete ' not in system_lua)
            ok('Packaged StandDefinitions identify expected character stats',
               'characterStat = "STAND_BASE_BODY"' in defs_lua
               and all(f'characterStat = "STAND_STAR_PLATINUM_BODY_L{tier}"' in defs_lua for tier in [3, 5, 6, 10, 12]))

            root_lsf = extract_dir / 'Public/StandPrototype/RootTemplates/_merged.lsf'
            root_lsx = extract_dir / 'Public/StandPrototype/RootTemplates/_merged.lsx'
            rc, output = convert_lsf_to_lsx(root_lsf, root_lsx)
            ok('Packaged RootTemplates/_merged.lsf converts for content validation',
               rc == 0,
               output[-500:] if rc != 0 else str(root_lsx))
            root_text = read_text(root_lsx)
            ok('Packaged BaseStand root template points to STAND_BASE_BODY',
               'Name" type="LSString" value="STANDPROTOTYPE_BASE_STAND"' in root_text
               and 'MapKey" type="FixedString" value="72b4f830-2f41-4f50-8f80-0f7cc1383d01"' in root_text
               and 'Stats" type="FixedString" value="STAND_BASE_BODY"' in root_text)
            ok('Packaged Star Platinum tier root templates point to tier bodies',
               all(f'Name" type="LSString" value="STANDPROTOTYPE_STAR_PLATINUM_L{tier}"' in root_text for tier in [3, 5, 6, 10, 12])
               and all(f'Stats" type="FixedString" value="STAND_STAR_PLATINUM_BODY_L{tier}"' in root_text for tier in [3, 5, 6, 10, 12]))
    finally:
        shutil.rmtree(extract_dir, ignore_errors=True)

    print('PACKAGE VALIDATION RESULTS')
    failed = [check for check in checks if not check[1]]
    for name, condition, detail in checks:
        status = 'PASS' if condition else 'FAIL'
        print(f'- {status}: {name}' + (f' :: {detail}' if detail else ''))

    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
