#!/usr/bin/env python3
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent

checks = []
warnings = []

def ok(name, cond, detail=''):
    checks.append((name, bool(cond), detail))

def warn(name, detail=''):
    warnings.append((name, detail))

# Files exist
class_file = root / 'Public/StandPrototype/ClassDescriptions/ClassDescriptions.lsx'
prog_file = root / 'Public/StandPrototype/Progressions/Progressions.lsx'
passive_file = root / 'Public/StandPrototype/Stats/Generated/Data/StandPrototype_Passives.txt'
spell_file = root / 'Public/StandPrototype/Stats/Generated/Data/StandPrototype_Spells.txt'
stand_def = root / 'ScriptExtender/Lua/StandFramework/StandDefinitions.lua'
lua_system = root / 'ScriptExtender/Lua/StandFramework/StandSystem.lua'
build_sh = root / 'scripts/build.sh'

ok('ClassDescriptions exists', class_file.exists(), str(class_file))
ok('Progressions exists', prog_file.exists(), str(prog_file))

c = class_file.read_text() if class_file.exists() else ''
p = prog_file.read_text() if prog_file.exists() else ''
pa = passive_file.read_text() if passive_file.exists() else ''
sp = spell_file.read_text() if spell_file.exists() else ''
sd = stand_def.read_text() if stand_def.exists() else ''
ls = lua_system.read_text() if lua_system.exists() else ''
bs = build_sh.read_text() if build_sh.exists() else ''

# StandUser/TheStar records
ok('StandUser class record exists', 'value="StandUser"' in c and 'ClassDescription' in c, 'ClassDescriptions contains StandUser')
ok('TheStar subclass record exists', 'value="TheStar"' in c and 'ParentGuid' in c, 'ClassDescriptions contains TheStar + ParentGuid')
ok('StandUser multiclass class-description row exists', 'Name" type="LSString" value="StandUser"' in c and 'IsMulticlass" type="bool" value="true"' in c)

# Link proofs
stand_user_uuid = re.search(r'ClassUUID" type="FixedString" value="([^"]+)" />\s*\n\s*<attribute id="Description"[^\n]*\n\s*<attribute id="DisplayName"[^\n]*\n\s*<attribute id="Name" type="LSString" value="StandUser"', c)
the_star_parent_link = 'ParentGuid" type="guid" value="7a23b113-0a85-4f8f-86ca-7f88f5de9c61"' in c
ok('TheStar linked to StandUser parent guid', the_star_parent_link)
ok('StandUser progression offers TheStar subclass', 'SubClasses" type="LSString" value="TheStar"' in p)

# ASI cadence ownership and no subclass duplication at L12
ok('StandUser has ASI cadence at class levels 4/8/12',
   'Level" type="uint8" value="4"' in p and 'Level" type="uint8" value="8"' in p and 'Level" type="uint8" value="12"' in p and p.count('AllowImprovement" type="LSString" value="Yes"') >= 3)
the_star_l12_chunk = ''
for m in re.finditer(r'<node id="Progression">([\s\S]*?)</node>', p):
    chunk = m.group(1)
    if 'Name" type="FixedString" value="TheStar"' in chunk and 'Level" type="uint8" value="12"' in chunk:
        the_star_l12_chunk = chunk
        break
ok('TheStar level 12 does not duplicate ASI feat selection',
   the_star_l12_chunk != '' and 'AllowImprovement" type="LSString" value="Yes"' not in the_star_l12_chunk)

# Progression grant references exist
passives_added = re.findall(r'PassivesAdded" type="LSString" value="([^"]*)"', p)
selectors = re.findall(r'Selectors" type="LSString" value="([^"]*)"', p)
all_passives = set()
for val in passives_added:
    for tok in [t.strip() for t in val.split(';') if t.strip()]:
        all_passives.add(tok)
for val in selectors:
    for m in re.finditer(r'AddPassive\(([^\)]+)\)', val):
        all_passives.add(m.group(1).strip())

all_spells = set()
for val in selectors:
    for m in re.finditer(r'AddSpell\(([^\)]+)\)', val):
        all_spells.add(m.group(1).strip())

missing_passives = [x for x in sorted(all_passives) if f'new entry "{x}" "PassiveData"' not in pa]
missing_spells = [x for x in sorted(all_spells) if f'new entry "{x}" "SpellData"' not in sp]
ok('All progression-referenced passives exist', not missing_passives, ', '.join(missing_passives) if missing_passives else 'ok')
ok('All progression-referenced spells exist', not missing_spells, ', '.join(missing_spells) if missing_spells else 'ok')

# Manifest/Withdraw only via progression (not in base passive)
base_passive_line = re.search(r'new entry "STAND_USER_BASE_CLASS_PASSIVE" "PassiveData"[\s\S]*?data "Properties" "([^"]*)"', pa)
base_props = base_passive_line.group(1) if base_passive_line else ''
ok('Base class passive does not directly grant Manifest/Withdraw', 'Target_Stand_Manifest' not in base_props and 'Target_Stand_Withdraw' not in base_props, base_props)
ok('Manifest/Withdraw are progression granted', 'AddSpell(Target_Stand_Manifest)' in p and 'AddSpell(Target_Stand_Withdraw)' in p)
standuser_l1_chunk = ''
for m in re.finditer(r'<node id="Progression">([\s\S]*?)</node>', p):
    chunk = m.group(1)
    if 'Name" type="FixedString" value="StandUser"' in chunk and 'Level" type="uint8" value="1"' in chunk:
        standuser_l1_chunk = chunk
        break
ok('No level-1 stand manifest grant in progression',
   standuser_l1_chunk != '' and 'AddSpell(Target_Stand_Manifest)' not in standuser_l1_chunk)

# Lua not granting level 1 manifest
ok('StandDefinitions has no level [1] gate', '[1]' not in sd)
ok('StandDefinitions level 3 grants manifest/withdraw', '[3]' in sd and 'Target_Stand_Manifest' in sd and 'Target_Stand_Withdraw' in sd)
ok('Runtime progression uses stand-user progression level helper (multiclass-safe gate)', 'GetUserStandProgressLevel' in ls)
ok('Runtime has stale state cleanup helper', 'CleanupStaleState' in ls)

# Level gates match
levels_lua = sorted(set(int(x) for x in re.findall(r'\[(\d+)\]\s*=\s*\{', sd)))
levels_star_prog = []
for m in re.finditer(r'<node id="Progression">([\s\S]*?)</node>', p):
    chunk = m.group(1)
    if 'Name" type="FixedString" value="TheStar"' in chunk:
        lv = re.search(r'Level" type="uint8" value="(\d+)"', chunk)
        if lv:
            levels_star_prog.append(int(lv.group(1)))
levels_star_prog = sorted(set(levels_star_prog))
ok('TheStar level gates match Lua and Progressions', levels_lua == levels_star_prog, f'lua={levels_lua} prog={levels_star_prog}')

# Obsolete feat-first path not active
feat_file = root / 'Public/StandPrototype/Stats/Generated/Data/StandPrototype_Feats.txt'
ok('Obsolete feats file removed', not feat_file.exists())
text_blobs = []
for path in root.rglob('*'):
    if path.is_file() and path.suffix.lower() in {'.md','.txt','.lsx','.lua','.sh','.py','.example','.env'}:
        if path.name == 'validate_static.py':
            continue
        try:
            text_blobs.append(path.read_text())
        except Exception:
            pass
joined = '\n'.join(text_blobs)
ok('No active feat unlock references', 'Feat_StandUserBase' not in joined and 'Feat_Arcana_TheStar' not in joined)

# dist/.build_stage not source of truth
ok('Build script rebuilds and does not trust existing stage dir',
   ('prepare_stage_dir' in bs or 'rm -rf "$STAGE_DIR"' in bs) and 'cp -a "$MOD_ROOT/Public" "$STAGE_DIR/Public"' in bs)

# Runtime-uncertain warning: direct SelectSkills selector usage
if 'SelectSkills(2,Acrobatics,Athletics,Insight,Intimidation,Perception,SleightOfHand,Stealth)' in p:
    warn(
        'Level 1 skill selection uses direct SelectSkills(2,...)',
        'Static validation passes, but BG3 character creation UI/runtime acceptance is unverified. Test: New Game -> StandUser -> verify exactly 2 skill picks from intended list.'
    )

# Report
failed = [c for c in checks if not c[1]]
print('STATIC VALIDATION RESULTS')
for name, cond, detail in checks:
    status = 'PASS' if cond else 'FAIL'
    print(f'- {status}: {name}' + (f' :: {detail}' if detail else ''))

if warnings:
    print('\nSTATIC VALIDATION WARNINGS')
    for name, detail in warnings:
        print(f'- WARN: {name}' + (f' :: {detail}' if detail else ''))

if failed:
    sys.exit(1)
