#!/usr/bin/env python3
import re
import sys
import json
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
character_file = root / 'Public/StandPrototype/Stats/Generated/Data/Character.txt'
item_file = root / 'Public/StandPrototype/Stats/Generated/Data/StandPrototype_Items.txt'
loca_file = root / 'Localization/English/StandPrototype.loca.xml'
loca_xml_file = root / 'Localization/English/StandPrototype.xml'
loca_bin_file = root / 'Localization/English/StandPrototype.loca'
stand_def = root / 'ScriptExtender/Lua/StandFramework/StandDefinitions.lua'
lua_system = root / 'ScriptExtender/Lua/StandFramework/StandSystem.lua'
se_config = root / 'ScriptExtender/Config.json'
build_sh = root / 'scripts/build.sh'
install_sh = root / 'scripts/install.sh'
skill_list_file = root / 'Public/StandPrototype/Lists/SkillLists.lsx'
spell_list_file = root / 'Public/StandPrototype/Lists/SpellLists.lsx'
ability_preset_file = root / 'Public/StandPrototype/CharacterCreationPresets/AbilityDistributionPresets.lsx'
star_platinum_template_file = root / 'Public/StandPrototype/RootTemplates/StandPrototype_StarPlatinum.lsx'
base_stand_template_file = root / 'Public/StandPrototype/RootTemplates/StandPrototype_BaseStand.lsx'
merged_root_template_source_file = root / 'Public/StandPrototype/RootTemplates/_merged.lsf.lsx'

ok('ClassDescriptions exists', class_file.exists(), str(class_file))
ok('Progressions exists', prog_file.exists(), str(prog_file))
ok('SkillLists exists', skill_list_file.exists(), str(skill_list_file))
ok('SpellLists exists', spell_list_file.exists(), str(spell_list_file))
ok('AbilityDistributionPresets exists', ability_preset_file.exists(), str(ability_preset_file))
ok('Star Platinum root template exists', star_platinum_template_file.exists(), str(star_platinum_template_file))
ok('Base Stand root template exists', base_stand_template_file.exists(), str(base_stand_template_file))
ok('Merged root template LSF source exists', merged_root_template_source_file.exists(), str(merged_root_template_source_file))
ok('Star Platinum character stats exist', character_file.exists(), str(character_file))
ok('StandPrototype item stats exist', item_file.exists(), str(item_file))
ok('Compiled localization file exists (.loca)',
   loca_bin_file.exists(),
   str(loca_bin_file))
ok('Localization source file exists (.loca.xml or .xml)',
   loca_file.exists() or loca_xml_file.exists(),
   f'{loca_file} | {loca_xml_file}')

c = class_file.read_text() if class_file.exists() else ''
p = prog_file.read_text() if prog_file.exists() else ''
pa = passive_file.read_text() if passive_file.exists() else ''
sp = spell_file.read_text() if spell_file.exists() else ''
char_stats = character_file.read_text() if character_file.exists() else ''
item_stats = item_file.read_text() if item_file.exists() else ''
loc = ''
if loca_file.exists():
    loc += loca_file.read_text()
if loca_xml_file.exists():
    loc += "\n" + loca_xml_file.read_text()
base_loc_xml = loca_xml_file.read_text() if loca_xml_file.exists() else (loca_file.read_text() if loca_file.exists() else '')
base_loc_handles = set(re.findall(r'contentuid="([^"]+)"', base_loc_xml))
sd = stand_def.read_text() if stand_def.exists() else ''
ls = lua_system.read_text() if lua_system.exists() else ''
bs = build_sh.read_text() if build_sh.exists() else ''
ins = install_sh.read_text() if install_sh.exists() else ''
se_cfg_text = se_config.read_text() if se_config.exists() else ''
sl = skill_list_file.read_text() if skill_list_file.exists() else ''
spl = spell_list_file.read_text() if spell_list_file.exists() else ''
ap = ability_preset_file.read_text() if ability_preset_file.exists() else ''
spt = star_platinum_template_file.read_text() if star_platinum_template_file.exists() else ''
bst = base_stand_template_file.read_text() if base_stand_template_file.exists() else ''
mrt = merged_root_template_source_file.read_text() if merged_root_template_source_file.exists() else ''

def stats_entry_block(text: str, entry_name: str) -> str:
    match = re.search(rf'new entry "{re.escape(entry_name)}"\n([\s\S]*?)(?=\nnew entry "|\Z)', text)
    return match.group(1) if match else ''

def collect_handle_texts(label: str, text: str):
    out = {}
    for kind, handle, value in re.findall(r'data "(DisplayName|Description)" "([^";]+);([^"]*)"', text):
        out.setdefault(handle, set()).add(value)
    return out

inline_handle_texts = {}
for source_label, source_text in [
    ('spells', sp),
    ('passives', pa),
    ('items', item_stats),
]:
    for handle, values in collect_handle_texts(source_label, source_text).items():
        inline_handle_texts.setdefault(handle, set()).update(values)

loc_handle_texts = {}
for handle, value in re.findall(r'<content contentuid="([^"]+)" version="1">([\s\S]*?)</content>', loc):
    loc_handle_texts.setdefault(handle, set()).add(value)

inline_handle_collisions = {
    handle: values
    for handle, values in inline_handle_texts.items()
    if len(values) > 1
}
loc_handle_collisions = {
    handle: values
    for handle, values in loc_handle_texts.items()
    if len(values) > 1
}
inline_loca_mismatches = {
    handle: (inline_handle_texts[handle], loc_handle_texts.get(handle, set()))
    for handle in inline_handle_texts
    if handle in loc_handle_texts and inline_handle_texts[handle] != loc_handle_texts[handle]
}
ok('No stat DisplayName/Description localization handle collisions',
   not inline_handle_collisions,
   '; '.join(f'{h}: {sorted(v)}' for h, v in inline_handle_collisions.items()))
ok('No duplicate localization content handles with conflicting text',
   not loc_handle_collisions,
   '; '.join(f'{h}: {sorted(v)}' for h, v in loc_handle_collisions.items()))
ok('Inline stat localization handles match localization XML text',
   not inline_loca_mismatches,
   '; '.join(f'{h}: stats={sorted(v[0])} loca={sorted(v[1])}' for h, v in inline_loca_mismatches.items()))

# StandUser/TheStar records
class_chunks = re.findall(r'<node id="ClassDescription">([\s\S]*?)</node>', c)
standuser_chunks = [
    ch for ch in class_chunks
    if ('Name" type="FixedString" value="StandUser"' in ch or 'Name" type="LSString" value="StandUser"' in ch)
]
standuser_base_chunk = next((ch for ch in standuser_chunks if 'IsMulticlass" type="bool" value="true"' not in ch), '')
standuser_multi_chunk = next((ch for ch in standuser_chunks if 'IsMulticlass" type="bool" value="true"' in ch), '')
the_star_chunk = next((
    ch for ch in class_chunks
    if ('Name" type="FixedString" value="TheStar"' in ch or 'Name" type="LSString" value="TheStar"' in ch)
), '')

ok('StandUser class record exists', len(standuser_chunks) >= 1, 'ClassDescriptions contains StandUser')
ok('TheStar subclass record exists', the_star_chunk != '' and 'ParentGuid' in the_star_chunk, 'ClassDescriptions contains TheStar + ParentGuid')
ok('StandUser has a single class-description row (no duplicate CC entry)', len(standuser_chunks) == 1)

required_standuser_attrs = [
    'BaseHp',
    'CanLearnSpells',
    'CharacterCreationPose',
    'ClassEquipment',
    'ClassHotbarColumns',
    'CommonHotbarColumns',
    'Description',
    'DisplayName',
    'HpPerLevel',
    'ItemsHotbarColumns',
    'LearningStrategy',
    'MustPrepareSpells',
    'ProgressionTableUUID',
    'SoundClassType',
    'SpellCastingAbility',
    'UUID'
]
ok(
    'StandUser base class row has required class attributes',
    standuser_base_chunk != '' and all(f'id="{attr}"' in standuser_base_chunk for attr in required_standuser_attrs)
)

equipment_text = (root / 'Public/StandPrototype/Stats/Generated/Equipment.txt').read_text()
equipment_names = set(re.findall(r'new equipment "([^"]+)"', equipment_text))
class_equipment_values = re.findall(r'id="ClassEquipment"\s+type="FixedString"\s+value="([^"]+)"', c)
standuser_class_equipment = re.search(r'id="ClassEquipment"\s+type="FixedString"\s+value="([^"]+)"', standuser_base_chunk)
standuser_class_equipment = standuser_class_equipment.group(1) if standuser_class_equipment else ''
ok('EQP_CC_StandUser equipment row exists', 'EQP_CC_StandUser' in equipment_names)
ok('ClassEquipment points to existing equipment rows',
   all(value in equipment_names for value in class_equipment_values),
   f'classEquipment={class_equipment_values} equipment={sorted(equipment_names)}')
ok('StandUser ClassEquipment is EQP_CC_StandUser',
   standuser_class_equipment == 'EQP_CC_StandUser',
   standuser_class_equipment)
ok('Stand User equipment has clothing and no weapon set',
   'add equipment entry "STANDUSER_FIELD_JACKET"' in equipment_text
   and 'add equipment entry "STANDUSER_FIELD_BOOTS"' in equipment_text
   and 'initialweaponset' not in equipment_text
   and 'EQP_Unarmed' not in equipment_text)

# Link proofs
stand_user_uuid_match = re.search(r'id="UUID"\s+type="guid"\s+value="([^"]+)"', standuser_base_chunk)
the_star_parent_match = re.search(r'id="ParentGuid"\s+type="guid"\s+value="([^"]+)"', the_star_chunk)
the_star_parent_link = bool(stand_user_uuid_match and the_star_parent_match and stand_user_uuid_match.group(1) == the_star_parent_match.group(1))
ok('TheStar linked to StandUser parent guid', the_star_parent_link)
ok('StandUser progression offers TheStar subclass',
   'node id="SubClasses"' in p and 'ce55f9d6-1dd2-42bb-8b2f-e42eb2a87c12' in p)

# Localization coverage for class/subclass display strings.
for handle in (
    'h4f6dfd10g4ca5g4b2fg8c76g1df52ef9c8c1',
    'h1a91b8c8g7d65g4c7eg9f1ag36640f1499ef',
    'h84f4a14eg56e5g4ec8ga998g67fe7dcef8b3',
    'h4e09986egf919g4605gb7f5g62cf7b2a6e54',
    'h901ea68cg1717g46d6g8d95g396ab70c4cf6',
):
    ok(f'Localization contains handle {handle}', f'contentuid="{handle}"' in loc)

# If gender override localization files exist, keep them in sync with base handles.
for gender in ('Female', 'Neutral'):
    g_xml = root / f'Localization/English/Gender/{gender}/StandPrototype.xml'
    g_loca = root / f'Localization/English/Gender/{gender}/StandPrototype.loca'
    if g_xml.exists():
        g_text = g_xml.read_text()
        g_handles = set(re.findall(r'contentuid="([^"]+)"', g_text))
        missing = sorted(base_loc_handles - g_handles)
        ok(f'{gender} gender localization mirrors base handles', not missing, ', '.join(missing[:6]) if missing else '')
        ok(f'{gender} gender compiled .loca exists', g_loca.exists(), str(g_loca))

# ASI cadence ownership and no subclass duplication at L12
ok('StandUser has ASI cadence at class levels 4/8/12',
   'Level" type="uint8" value="4"' in p and 'Level" type="uint8" value="8"' in p and 'Level" type="uint8" value="12"' in p and p.count('AllowImprovement" type="bool" value="true"') >= 3)
the_star_l12_chunk = ''
for m in re.finditer(r'<node id="Progression">([\s\S]*?)</node>', p):
    chunk = m.group(1)
    if 'value="TheStar"' in chunk and 'Level" type="uint8" value="12"' in chunk:
        the_star_l12_chunk = chunk
        break
ok('TheStar level 12 does not duplicate ASI feat selection',
   the_star_l12_chunk != '' and 'AllowImprovement" type="bool" value="true"' not in the_star_l12_chunk)

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

spell_list_map = {}
for entry in re.findall(r'<node id="SpellList">([\s\S]*?)</node>', spl):
    uuid_match = re.search(r'UUID"\s+type="guid"\s+value="([^"]+)"', entry)
    spells_match = re.search(r'Spells"\s+type="LSString"\s+value="([^"]*)"', entry)
    if not uuid_match:
        continue
    spells = []
    if spells_match:
        spells = [s.strip() for s in spells_match.group(1).split(';') if s.strip()]
    spell_list_map[uuid_match.group(1)] = spells

spell_list_uuids = set()
for val in selectors:
    for m in re.finditer(r'AddSpells\(([0-9a-fA-F-]+)', val):
        spell_list_uuids.add(m.group(1).strip())

all_spells = set()
for uuid in spell_list_uuids:
    for spell in spell_list_map.get(uuid, []):
        all_spells.add(spell)

def has_entry(blob: str, name: str, data_type: str) -> bool:
    pattern = rf'new entry "{re.escape(name)}"(?:\s+"[^"]+")?\s*\n\s*type "{re.escape(data_type)}"'
    return re.search(pattern, blob) is not None

missing_passives = [x for x in sorted(all_passives) if not has_entry(pa, x, 'PassiveData')]
missing_spells = [x for x in sorted(all_spells) if not has_entry(sp, x, 'SpellData')]
ok('All progression-referenced passives exist', not missing_passives, ', '.join(missing_passives) if missing_passives else 'ok')
ok('All progression-referenced spells exist', not missing_spells, ', '.join(missing_spells) if missing_spells else 'ok')
ok('All AddSpells selectors reference known SpellLists UUIDs',
   spell_list_uuids.issubset(set(spell_list_map.keys())),
   ', '.join(sorted(spell_list_uuids - set(spell_list_map.keys()))))

# SpellData schema sanity checks (common runtime-cast failure causes)
spell_entries = []
for match in re.finditer(r'new entry "([^"]+)"(?:\s+"[^"]+")?\s*\n\s*type "SpellData"\n([\s\S]*?)(?=\nnew entry "|\Z)', sp):
    spell_entries.append((match.group(1), match.group(2)))

missing_cast_text_event = []
missing_spell_animation = []
target_missing_roll_or_props = []
target_missing_radius = []
spell_prefix_mismatches = []
stand_technique_missing_cost = []
stand_technique_empty_cost = []

command_spell_ids = {
    'Shout_Stand_Manifest',
    'Shout_Stand_Withdraw',
    'Shout_Stand_Reposition',
    'Shout_Stand_CombatPrediction',
}
internal_spell_ids = {
    'Zone_Stand_TimeStopPulse',
}

for spell_name, body in spell_entries:
    if 'data "CastTextEvent"' not in body:
        missing_cast_text_event.append(spell_name)
    if 'data "SpellAnimation"' not in body:
        missing_spell_animation.append(spell_name)

    spell_type_match = re.search(r'data "SpellType" "([^"]+)"', body)
    spell_type = spell_type_match.group(1) if spell_type_match else ''
    spell_prefix = spell_name.split('_', 1)[0] if '_' in spell_name else ''
    if spell_prefix in {'Target', 'Shout', 'Zone', 'Projectile'} and spell_prefix != spell_type:
        spell_prefix_mismatches.append(f'{spell_name}: prefix={spell_prefix} SpellType={spell_type}')
    if '_Stand_' in spell_name and spell_name not in command_spell_ids and spell_name not in internal_spell_ids:
        use_cost_match = re.search(r'data "UseCosts" "([^"]*)"', body)
        if not use_cost_match:
            stand_technique_missing_cost.append(spell_name)
        elif use_cost_match.group(1).strip() == '':
            stand_technique_empty_cost.append(spell_name)
    if spell_type == 'Target':
        has_roll = 'data "SpellRoll"' in body
        has_props = 'data "SpellProperties"' in body
        if not (has_roll or has_props):
            target_missing_roll_or_props.append(spell_name)
        if 'data "TargetRadius"' not in body:
            target_missing_radius.append(spell_name)

ok('All SpellData entries define CastTextEvent',
   not missing_cast_text_event,
   ', '.join(missing_cast_text_event) if missing_cast_text_event else 'ok')
ok('All SpellData entries define SpellAnimation',
   not missing_spell_animation,
   ', '.join(missing_spell_animation) if missing_spell_animation else 'ok')
ok('Custom Stand SpellData entries are self-contained and do not inherit existing spells/actions',
   'using "' not in sp,
   'Do not use SpellData inheritance for Stand actions; inherited class/spell metadata caused spellbook/plus-sign UI regressions.')
ok('Target SpellData entries define SpellRoll or SpellProperties',
   not target_missing_roll_or_props,
   ', '.join(target_missing_roll_or_props) if target_missing_roll_or_props else 'ok')
ok('Target SpellData entries define TargetRadius',
   not target_missing_radius,
   ', '.join(target_missing_radius) if target_missing_radius else 'ok')
ok('SpellData technical prefixes match SpellType',
   not spell_prefix_mismatches,
   '; '.join(spell_prefix_mismatches) if spell_prefix_mismatches else 'ok')
ok('Every Stand combat technique has explicit non-empty UseCosts',
   not stand_technique_missing_cost and not stand_technique_empty_cost,
   'missing=' + ', '.join(stand_technique_missing_cost) + ' empty=' + ', '.join(stand_technique_empty_cost)
   if (stand_technique_missing_cost or stand_technique_empty_cost) else 'ok')

spell_entry_names = {name for name, _ in spell_entries}
vanilla_spell_entry_names = {
    # Data-owned baseline action from Shared.pak. This is intentionally unlocked
    # on Stand bodies as a control case: if vanilla unarmed also cannot target,
    # the issue is actor/control state, not custom SpellData.
    'Target_UnarmedAttack',
}
unlock_spell_refs = set(re.findall(r'UnlockSpell\(([^)]+)\)', char_stats + '\n' + pa + '\n' + item_stats))
missing_unlock_spell_refs = sorted(ref for ref in unlock_spell_refs if ref not in spell_entry_names and ref not in vanilla_spell_entry_names)
ok('Character/passive/item UnlockSpell references point to real SpellData entries',
   not missing_unlock_spell_refs,
   ', '.join(missing_unlock_spell_refs) if missing_unlock_spell_refs else 'ok')

# Manifest/Withdraw only via progression (not in base passive)
base_passive_line = re.search(
    r'new entry "STAND_USER_BASE_CLASS_PASSIVE"(?:\s+"[^"]+")?[\s\S]*?data "(?:Boosts|Properties)" "([^"]*)"',
    pa
)
base_props = base_passive_line.group(1) if base_passive_line else ''
ok('Base class passive does not directly grant Manifest/Withdraw', 'Shout_Stand_Manifest' not in base_props and 'Shout_Stand_Withdraw' not in base_props, base_props)
ok('Manifest/Withdraw are progression granted via AddSpells list',
   'AddSpells(a6f8f7c9-8475-46f5-9f7f-24f9dcb7c9a1)' in p)
standuser_l1_chunk = ''
for m in re.finditer(r'<node id="Progression">([\s\S]*?)</node>', p):
    chunk = m.group(1)
    if 'value="StandUser"' in chunk and 'Level" type="uint8" value="1"' in chunk:
        standuser_l1_chunk = chunk
        break
ok('Level 1 grants user command actions only',
   standuser_l1_chunk != '' and 'AddSpells(a6f8f7c9-8475-46f5-9f7f-24f9dcb7c9a1)' in standuser_l1_chunk)

stand_skill_list_uuid = '0d9c53e6-52c4-4c21-89f5-60467f0d95c3'
ok('Level 1 uses GUID-based SelectSkills selector',
   standuser_l1_chunk != '' and f'SelectSkills({stand_skill_list_uuid},2)' in standuser_l1_chunk)
expected_skills = [
    'Acrobatics',
    'Athletics',
    'Insight',
    'Intimidation',
    'Perception',
    'SleightOfHand',
    'Stealth',
]
skill_list_has_uuid = f'UUID" type="guid" value="{stand_skill_list_uuid}"' in sl
skill_list_has_skills = all(skill in sl for skill in expected_skills)
ok('Stand User skill list UUID exists with expected skills',
   skill_list_has_uuid and skill_list_has_skills)

standuser_l2_chunk = ''
for m in re.finditer(r'<node id="Progression">([\s\S]*?)</node>', p):
    chunk = m.group(1)
    if 'value="StandUser"' in chunk and 'Level" type="uint8" value="2"' in chunk:
        standuser_l2_chunk = chunk
        break
ok('Level 2 grants user anchor/resource loop',
   standuser_l2_chunk != ''
   and 'AddSpells(5e6b735e-7f23-4a8a-b18f-a88f38ab7ec6)' in standuser_l2_chunk
   and 'STAND_USER_SPIRIT_POOL_TIER1' in standuser_l2_chunk)

combat_reading_cost_ok = bool(re.search(
    r'new entry "Shout_Stand_CombatPrediction"(?:\s+"[^"]+")?[\s\S]*?data "UseCosts" "BonusActionPoint:1;KiPoint:1"',
    sp
))
ok('Combat Reading consumes KiPoint resource', combat_reading_cost_ok)

def spell_has_use_cost(spell_name: str, use_cost: str) -> bool:
    pattern = rf'new entry "{re.escape(spell_name)}"(?:\s+"[^"]+")?\s*\n\s*type "SpellData"\n([\s\S]*?)(?=\nnew entry "|\Z)'
    match = re.search(pattern, sp)
    return bool(match and f'data "UseCosts" "{use_cost}"' in match.group(1))

ok('Manifest and Withdraw are free actions',
   spell_has_use_cost('Shout_Stand_Manifest', '')
   and spell_has_use_cost('Shout_Stand_Withdraw', ''))
ok('Stand attack techniques use action economy',
   all(spell_has_use_cost(name, 'ActionPoint:1') for name in [
       'Target_Stand_BasicStrike',
       'Target_Stand_BasicBarrage',
       'Target_Stand_Barrage',
       'Target_Stand_Rush',
       'Target_Stand_StarFinger',
       'Target_Stand_RelentlessBarrage',
   ]))
ok('Base Stand Guard is a manual bonus-action guard button',
   spell_has_use_cost('Shout_Stand_BasicGuard', 'BonusActionPoint:1'))
ok('Time Stop is a bonus action capstone',
   spell_has_use_cost('Shout_Stand_TimeStop', 'BonusActionPoint:1'))
stand_martial_action_ids = [
    'Target_Stand_BasicStrike',
    'Target_Stand_BasicBarrage',
    'Target_Stand_Barrage',
    'Target_Stand_Rush',
    'Target_Stand_StarFinger',
    'Target_Stand_RelentlessBarrage',
]
stand_martial_blocks = {
    spell_id: stats_entry_block(sp, spell_id)
    for spell_id in stand_martial_action_ids
}
ok('Stand martial target techniques do not inherit spell/class selector actions',
   all('using "StunningStrike_Unarmed"' not in block and 'SpellStyleGroup" "Class"' not in block for block in stand_martial_blocks.values())
   and 'StunningStrike_Unarmed' not in sp,
   'StunningStrike_Unarmed and SpellStyleGroup Class create spell-like/upcast/ability-selector UI for martial techniques.')
ok('Stand martial target techniques expose unarmed attack UX',
   all('data "SpellRoll" "Attack(AttackType.MeleeUnarmedAttack)"' in block
       and 'data "TooltipAttackSave" "MeleeUnarmedAttack"' in block
       and 'data "PreviewCursor" "Melee"' in block
       and 'data "VerbalIntent" "Damage"' in block
       and 'data "TargetConditions" "not Self() and not Dead()"' in block
       for block in stand_martial_blocks.values()))
ok('Stand martial target techniques mirror vanilla unarmed action cast contract',
   all('data "Cooldown"' not in block for block in stand_martial_blocks.values())
   and all('8b8bb757-21ce-4e02-a2f3-97d55cf2f90b' in block for block in stand_martial_blocks.values())
   and all('data "TargetCeiling" "0"' in block and 'data "TargetFloor" ".25"' in block for block in stand_martial_blocks.values()),
   'Target_UnarmedAttack has no per-turn cooldown, has TargetCeiling/TargetFloor, and uses the standard unarmed melee animation row.')
ok('Stand martial target techniques do not require a melee weapon range',
   all('data "WeaponTypes" "Melee"' not in block and 'data "WeaponType" "Melee"' not in block for block in stand_martial_blocks.values())
   and all('data "TargetRadius" "MeleeMainWeaponRange"' not in block for block in stand_martial_blocks.values())
   and all('data "TargetRadius" "2.5"' in stand_martial_blocks[spell_id] for spell_id in [
       'Target_Stand_BasicStrike',
       'Target_Stand_BasicBarrage',
       'Target_Stand_Barrage',
       'Target_Stand_Rush',
       'Target_Stand_RelentlessBarrage',
   ])
   and 'data "TargetRadius" "4"' in stand_martial_blocks['Target_Stand_StarFinger'],
   'Unarmed Stand techniques must not depend on an equipped melee weapon range; use fixed close-range reach to avoid collision/pathing failures on small or flying targets.')
ok('Stand-owned techniques do not use class spell presentation metadata',
   all('SpellStyleGroup" "Class"' not in stats_entry_block(sp, spell_id) for spell_id in stand_martial_action_ids + [
       'Shout_Stand_BasicGuard',
       'Shout_Stand_Intercept',
       'Shout_Stand_TimeStop',
   ]),
   'Stand-owned actions should present as innate techniques, not class spell-selection actions.')

# Lua progression structure
base_stand_match = re.search(r'BaseStand\s*=\s*\{([\s\S]*?)\n\s*\},\n\s*TheStar\s*=', sd)
the_star_match = re.search(r'TheStar\s*=\s*\{([\s\S]*?)\n\s*\}\n\s*\}', sd)
base_stand_block = base_stand_match.group(1) if base_stand_match else ''
the_star_block = the_star_match.group(1) if the_star_match else ''
ok('BaseStand exists only as the default unawakened Stand, not as a TheStar fallback',
   'defaultArcana = "BaseStand"' in sd
   and 'BaseStand' in sd
   and 'standName = "Stand"' in base_stand_block
   and 'summonTemplate = "STANDPROTOTYPE_BASE_STAND_72b4f830-2f41-4f50-8f80-0f7cc1383d01"' in base_stand_block
   and 'fallbackSummonTemplate' not in base_stand_block
   and '[1]' in base_stand_block
   and 'Target_Stand_BasicStrike' in base_stand_block
   and 'Target_Stand_BasicBarrage' in base_stand_block
   and 'Shout_Stand_BasicGuard' in base_stand_block
   and 'Target_Stand_Barrage' not in base_stand_block
   and 'Target_Stand_StarFinger' not in base_stand_block
   and 'Shout_Stand_TimeStop' not in base_stand_block
   and 'Shout_Stand_Intercept' not in base_stand_block)
ok('The Star never references BaseStand or a fallback template',
   '[1]' not in the_star_block
   and 'standName = "Star Platinum"' in the_star_block
   and 'summonTemplate = "STANDPROTOTYPE_STAR_PLATINUM_L3_f50e6a61-772e-45c9-bfd6-45e68d33a4c0"' in the_star_block
   and 'fallbackSummonTemplate' not in the_star_block
   and 'STANDPROTOTYPE_BASE_STAND' not in the_star_block
   and 'STAND_BASE_BODY' not in the_star_block)
ok('Stand summonTemplate values use official root-template Name_UUID format for CreateAt',
   'summonTemplate = "STANDPROTOTYPE_BASE_STAND_72b4f830-2f41-4f50-8f80-0f7cc1383d01"' in sd
   and 'entityTemplate = "STANDPROTOTYPE_BASE_STAND_72b4f830-2f41-4f50-8f80-0f7cc1383d01"' in sd
   and 'summonTemplate = "STANDPROTOTYPE_STAR_PLATINUM_L3_f50e6a61-772e-45c9-bfd6-45e68d33a4c0"' in sd
   and 'entityTemplate = "STANDPROTOTYPE_STAR_PLATINUM_L3_f50e6a61-772e-45c9-bfd6-45e68d33a4c0"' in sd)
ok('TheStar has no fallbackSummonTemplate',
   'fallbackSummonTemplate' not in the_star_block)
ok('TheStar does not reference stock strong-human fallback',
   'BASE_Humans_Male_Strong' not in the_star_block)
ok('StandDefinitions keeps user actions separate from stand actions',
   'userActions' in sd and 'standActions' in sd and 'Shout_Stand_Manifest' in sd and 'Target_Stand_Barrage' in sd)
ok('StandDefinitions has requested Star Platinum stand action ids',
   all(x in sd for x in [
       'Target_Stand_Barrage',
       'Shout_Stand_Intercept',
       'Target_Stand_StarFinger',
       'Target_Stand_Rush',
       'Target_Stand_RelentlessBarrage',
       'Shout_Stand_TimeStop',
   ]))
ok('The Star static spell lists do not directly grant stand combat spells',
   not any(x in spl for x in [
       'Target_Stand_Barrage',
       'Shout_Stand_Intercept',
       'Target_Stand_Rush',
       'Target_Stand_StarFinger',
       'Target_Stand_RelentlessBarrage',
       'Shout_Stand_TimeStop',
   ]))
ok('Obsolete Stand combat spell entries removed',
   all(x not in sp and x not in sd and x not in ls for x in [
       'Target_Stand_HeavyPunch',
       'Target_Stand_PrecisionCounter',
       'Target_Stand_LeapCloser',
   ]))
ok('Obsolete RushUltimate spell entry removed',
   'Target_Stand_RushUltimate' not in sp
   and 'Target_Stand_RushUltimate' not in sd
   and 'Target_Stand_RushUltimate' not in ls)
ok('Runtime does not manage Stand spellbooks through AddSpell/RemoveSpell',
   'Osi.AddSpell' not in ls
   and 'Osi.RemoveSpell' not in ls
   and 'repairStandActionSpellbook' not in ls
   and 'enforceUserCommandOnlySpellbook' not in ls
   and 'USER_FORBIDDEN_STAND_SPELLS' not in ls
   and 'GLOBAL_INHERITED_STAND_SPELL_BLOCKLIST' not in ls)
ok('Runtime does not grant player command spells redundantly',
   'Osi.AddSpell(user' not in ls
   and 'grantUserTierActions' not in ls)
ok('Runtime only logs concrete Stand action ownership',
   'verifyConcreteStandActionOwnership(user, state.stand, def)' in ls
   and 'collectActionsByLevel(def and def.standActions' in ls
   and 'ENABLE_RUNTIME_STAND_ACTION_REPAIR = false' in ls
   and 'Lua will not add/remove/lock Stand spells' in ls
   and 'grantStandTierSpells' not in ls)
ok('Runtime does not strip user weapons',
   'enforceCharacterUnarmed(user)' not in ls
   and 'enforceCharacterUnarmed(stand)' in ls)
ok('Runtime has verbose diagnostic logging helpers',
   'logInfo' in ls
   and 'logWarn' in ls
   and 'logError' in ls
   and 'safeOsi' in ls
   and 'statusSafe' in ls
   and 'SNAPSHOT' in ls)
ok('Manifest failures are loud and contextual',
   all(fragment in ls for fragment in [
       'manifest_non_stand_user',
       'manifest_missing_template',
       'manifest_fallback_guard',
       'manifest_no_position',
       'manifest_spawn_failed',
       'Manifest failed: concrete stand template did not spawn',
       'tryCreateStand CreateAt failed',
       'tryCreateStand CreateAtObject failed',
   ]))
ok('Spell handlers log Stand events and failures',
   all(fragment in (root / 'ScriptExtender/Lua/StandFramework/SpellHandlers.lua').read_text() for fragment in [
       'UsingSpell event',
       'CastSpellFailed event',
       'handleStandSpell start',
       'Spell handler error',
       'AttackedBy event',
   ]))
spell_handlers_text = (root / 'ScriptExtender/Lua/StandFramework/SpellHandlers.lua').read_text()
ok('Runtime logs caster/spell ownership for Stand technique usage',
   'UsingSpell event caster=[' in spell_handlers_text
   and 'spell=[' in spell_handlers_text
   and 'owner=[' in spell_handlers_text
   and 'controlTarget=[' in spell_handlers_text
   and 'direct SpellData technique has no Lua route' in spell_handlers_text)
ok('Runtime progression uses stand-user progression level helper (multiclass-safe gate)', 'GetUserStandProgressLevel' in ls)
ok('Runtime has stale state cleanup helper', 'CleanupStaleState' in ls)
ok('Runtime supports level 5 Star Finger gate', 'STAND_USER_LEVEL5_DISCIPLINE_NOTE' in ls and 'return 5' in ls)
ok('Runtime mirrors broad user feats/passives to stand',
   'KNOWN_FEAT_PASSIVE_SYNC_CANDIDATES' in ls
   and 'syncUserPassivesToStand' in ls
   and 'collectEntityComponentIds' in ls
   and 'Sentinel_Attack' in ls
   and 'TavernBrawler_Bonuses' in ls
   and 'not startsWith(passive, "STAND_")' in ls)
ok('Runtime does not mirror arbitrary user spells to stand',
   'syncUserSpellsToStand' not in ls
   and 'shouldMirrorUserSpell' not in ls
   and 'LearnedSpells' not in ls)
standuser_equipment_ids = [
    'STANDUSER_FIELD_JACKET',
    'STANDUSER_FIELD_BOOTS',
    'STANDUSER_SPIRIT_DRAUGHT',
    'STANDUSER_SOUL_ANCHOR_SCROLL',
    'STANDUSER_KEYCHAIN',
    'STANDUSER_ALCHEMY_SATCHEL',
    'STANDUSER_CAMP_COAT',
    'STANDUSER_CAMP_BOOTS',
    'STANDUSER_DYE_MIDNIGHT',
    'STANDUSER_DYE_STARDUST',
    'STANDUSER_DYE_ARCANA',
    'STANDUSER_CAMP_SUPPLIES',
]
stock_starter_ids = [
    'ARM_Monk',
    'ARM_Shoes_Monk',
    'OBJ_Potion_Healing',
    'OBJ_Scroll_Revivify',
    'OBJ_Keychain',
    'OBJ_Bag_AlchemyPouch',
    'ARM_Vanity_Body_Patriars_Black',
    'ARM_Camp_Shoes_E',
    'OBJ_Dye_BlackBlue',
    'OBJ_Dye_RoyalBlue',
    'OBJ_Dye_BluePurple',
    'OBJ_Backpack_CampSupplies',
]
ok('Stand User starting equipment uses mod-owned item stat ids',
   all(x in equipment_text for x in standuser_equipment_ids)
   and not any(f'add equipment entry "{x}"' in equipment_text for x in stock_starter_ids)
   and all(f'new entry "{x}"' in item_stats for x in standuser_equipment_ids))
ok('Stand User starting equipment has dedicated localization',
   all(handle in loc for handle in [
       'h00010001g0000g0000g0000g0000000000A0',
       'h00010001g0000g0000g0000g0000000000B7',
   ]))
ok('Stand command shouts are class actions, not spell-like casts',
   all(f'new entry "{spell}"' in sp for spell in [
       'Shout_Stand_Manifest',
       'Shout_Stand_Withdraw',
       'Shout_Stand_Reposition',
       'Shout_Stand_Intercept',
       'Shout_Stand_CombatPrediction',
       'Shout_Stand_TimeStop',
   ])
   and 'data "SpellFlags" "IsSpell;HasVerbalComponent;HasSomaticComponent"' not in sp
   and 'data "Ability" "Charisma"' not in sp
   and 'data "Ability" "Wisdom"' not in sp)
ok('Stand self-technique shouts have concrete SpellProperties',
   all(
       'data "SpellProperties"' in stats_entry_block(sp, spell)
       for spell in [
           'Shout_Stand_BasicGuard',
           'Shout_Stand_Intercept',
           'Shout_Stand_CombatPrediction',
           'Shout_Stand_TimeStop',
       ]
   ),
   'Official spell authoring expects SpellRoll or SpellProperties; Lua may add behavior, but these shouts still need concrete SpellData effects.')
ok('Runtime applies Star Platinum presentation hooks',
   'applyStandPresentation' in ls
   and 'GHOST_FX' in sd
   and 'WRAITH_GLOWING_EYES_TECHNICAL' in sd
   and 'standEquipmentTemplates' in sd
   and 'TemplateAddTo' in ls
   and 'CharacterEquipItem' in ls)
ok('Star Platinum has its own display-name handle',
   'h00010001g0000g0000g0000g00000000009A' in loc
   and 'Star Platinum' in loc
   and 'applyStandDisplayName' in ls
   and 'runtimeApplied=' in ls
   and 'DisplayName" type="TranslatedString" handle="h00010001g0000g0000g0000g00000000009A"' in spt)
ok('ORA Barrage is a fast multi-hit action',
   'new entry "Target_Stand_Barrage"' in sp
   and 'DealDamage(1d6+1,Bludgeoning);DealDamage(1d6+1,Bludgeoning);DealDamage(1d6+1,Bludgeoning)' in sp
   and '8b8bb757-21ce-4e02-a2f3-97d55cf2f90b' in stats_entry_block(sp, 'Target_Stand_Barrage'))
ok('Runtime does not strip or lock Stand actions; BG3 data owns the action set',
   'inheritedSpellBlocklist' not in sd
   and 'Target_LifeDrain_Wraith' not in ls
   and 'Target_CreateShadow_Wraith' not in ls
   and 'Removing locked future stand action' not in ls)
ok('Manifest creates Stand entities as temporary characters',
   'pcall(Osi.CreateAt, template, sx, y, sz, 1, 0, "")' in ls
   and 'pcall(Osi.CreateAtObject, template, user, 1, 0, "", 1)' in ls,
   'CreateAt/CreateAtObject must pass Temporary=1 so RequestDeleteTemporary can delete the Stand.')
ok('Withdraw deletes temporary Stand entities directly',
   'function StandSystem.Withdraw' in ls
   and 'queueStandDelete(user, stand, "withdraw")' in ls
   and 'requestDeleteTemporaryStand(user, stand, "withdraw")' in ls
   and 'clearStandOwnershipAfterDelete(user, stand, "withdraw")' in ls
   and 'Osi.RequestDeleteTemporary temporary-delete stand=' in ls
   and 'Osi.RemovePartyFollower temporary-delete stand=' in ls
   and 'Withdraw temporary delete queued and ownership cleared' in ls
   and 'killStandEntityForWithdraw' not in ls
   and 'finalizeDeadStandEntity' not in ls
   and 'queueStandDespawn' not in ls
   and 'Osi.Die' not in ls
   and 'Osi.RequestDelete ' not in ls
   and 'Withdraw death initiated; ownership retained until unload completes' not in ls
   and 'Manifest blocked: previous Stand is still owned and resolving death unload' not in ls,
   'Withdraw must use the official temporary character delete path, not death events or RequestDelete.')
ok('The Star has no generic fallback body path',
   'allowUserTemplateFallback' not in sd
   and 'summonTemplates' not in sd
   and 'Osi.GetTemplate, user' not in ls
   and '066133a8-5dce-4636-8ba1-13efb1140c54' not in sd
   and 'Shadow_Wraith_A' not in sd
   and 'fallbackSummonTemplate' not in sd
   and 'BASE_Humans_Male_Strong' not in sd)
ok('Runtime manifests only from resolved concrete stand definition',
   'def and def.summonTemplate' in ls
   and 'tryCreateStandFromDefinition(def, user, x, y, z)' in ls
   and 'concrete stand template did not spawn' in ls)
ok('Runtime mirrors linked damage in both directions with recursion guard',
   'OnStandDamaged' in ls
   and 'OnUserDamaged' in ls
   and 'DamageLinkGuard' in ls
   and 'StandSystem.OnUserDamaged(defender, source, damage)' in (root / 'ScriptExtender/Lua/StandFramework/SpellHandlers.lua').read_text())
ok('BaseStand and The Star have fixed 30ft/9m close-range tether',
   'BaseStand' in sd
   and 'TheStar' in sd
   and 'tetherRange = 9.0' in base_stand_block
   and sd.count('tetherRange = 9.0') >= 4
   and 'allowTetherScaling = false' in base_stand_block
   and sd.count('allowTetherScaling = false') >= 2
   and 'DEFAULT_CLOSE_RANGE_TETHER = 9.0' in ls
   and 'enforceStandTether' in ls
   and 'StandSystem.EnforceAllTethers' in ls
   and 'Ext.Events.Tick:Subscribe' in ls
   and 'server_tick' in ls)
ok('Star Platinum root template uses dedicated humanoid body, not stock Specter',
   'MapKey" type="FixedString" value="f50e6a61-772e-45c9-bfd6-45e68d33a4c0"' in spt
   and 'ParentTemplateId" type="FixedString" value="12c0a711-1459-48e2-a50e-7b792eee0918"' in spt
   and 'Stats" type="FixedString" value="STAND_STAR_PLATINUM_BODY_L3"' in spt
   and '066133a8-5dce-4636-8ba1-13efb1140c54' not in spt
   and 'h00010001g0000g0000g0000g00000000009A' in spt)
ok('Base Stand root template uses dedicated unawakened stand body',
   'MapKey" type="FixedString" value="72b4f830-2f41-4f50-8f80-0f7cc1383d01"' in bst
   and 'Stats" type="FixedString" value="STAND_BASE_BODY"' in bst
   and 'h00010001g0000g0000g0000g00000000009B' in bst
   and 'h00010001g0000g0000g0000g00000000009B' in loc
   and 'Stand' in loc)
ok('Merged root template source contains BaseStand and Star Platinum concrete templates',
   'Name" type="LSString" value="STANDPROTOTYPE_BASE_STAND"' in mrt
   and 'MapKey" type="FixedString" value="72b4f830-2f41-4f50-8f80-0f7cc1383d01"' in mrt
   and 'Stats" type="FixedString" value="STAND_BASE_BODY"' in mrt
   and all(f'Name" type="LSString" value="STANDPROTOTYPE_STAR_PLATINUM_L{tier}"' in mrt for tier in [3, 5, 6, 10, 12])
   and all(f'Stats" type="FixedString" value="STAND_STAR_PLATINUM_BODY_L{tier}"' in mrt for tier in [3, 5, 6, 10, 12]))
ok('Star Platinum character stats are unarmed humanoid stand stats',
   all(f'new entry "STAND_STAR_PLATINUM_BODY_L{tier}"' in char_stats for tier in [3, 5, 6, 10, 12])
   and 'new entry "STAND_ENTITY_BODY_BASE"' in char_stats
   and 'using "STAND_ENTITY_BODY_BASE"' in char_stats
   and 'using "_Summons"' in char_stats
   and 'using "HalfOrc_Barbarian"' not in char_stats
   and 'STAND_ENTITY_COMBAT_BODY' in char_stats
   and 'UnarmedAttackAbility" "Strength"' in char_stats
   and 'ActionResources" "ActionPoint:1;BonusActionPoint:1;ReactionActionPoint:1;Movement:9"' in char_stats)
ok('Stand character stats do not inherit class action kits',
   'using "HalfOrc_Barbarian"' not in char_stats
   and 'using "_Summons"' in char_stats,
   'Stand bodies should not inherit player/NPC class hotbar actions.')
base_stand_stat_block = stats_entry_block(char_stats, 'STAND_BASE_BODY')
base_stand_actions = [
    'Target_UnarmedAttack',
    'Target_Stand_BasicStrike',
    'Target_Stand_BasicBarrage',
    'Shout_Stand_BasicGuard',
]
star_combat_actions = [
    'Target_Stand_Barrage',
    'Shout_Stand_Intercept',
    'Target_Stand_StarFinger',
    'Target_Stand_Rush',
    'Target_Stand_RelentlessBarrage',
    'Shout_Stand_TimeStop',
]
ok('Base Stand character stats own generic baseline Stand actions',
   base_stand_stat_block != ''
   and all(f'UnlockSpell({spell})' in base_stand_stat_block for spell in base_stand_actions))
ok('Base Stand character stats do not own Star Platinum-specific actions',
   base_stand_stat_block != ''
   and all(f'UnlockSpell({spell})' not in base_stand_stat_block for spell in star_combat_actions))
star_tier_actions = {
    3: ['Target_UnarmedAttack', 'Target_Stand_Barrage', 'Shout_Stand_Intercept'],
    5: ['Target_UnarmedAttack', 'Target_Stand_Barrage', 'Shout_Stand_Intercept', 'Target_Stand_StarFinger'],
    6: ['Target_UnarmedAttack', 'Target_Stand_Barrage', 'Shout_Stand_Intercept', 'Target_Stand_StarFinger', 'Target_Stand_Rush'],
    10: ['Target_UnarmedAttack', 'Target_Stand_Barrage', 'Shout_Stand_Intercept', 'Target_Stand_StarFinger', 'Target_Stand_Rush', 'Target_Stand_RelentlessBarrage'],
    12: ['Target_UnarmedAttack'] + star_combat_actions,
}
ok('Star Platinum tier character stats own exact tier action sets',
   all(
       stats_entry_block(char_stats, f'STAND_STAR_PLATINUM_BODY_L{tier}') != ''
       and all(f'UnlockSpell({spell})' in stats_entry_block(char_stats, f'STAND_STAR_PLATINUM_BODY_L{tier}') for spell in actions)
       and all(f'UnlockSpell({spell})' not in stats_entry_block(char_stats, f'STAND_STAR_PLATINUM_BODY_L{tier}') for spell in star_combat_actions if spell not in actions)
       for tier, actions in star_tier_actions.items()
   ))
ok('Star Platinum tier character stats do not own generic BaseStand-only actions',
   all(
       all(f'UnlockSpell({spell})' not in stats_entry_block(char_stats, f'STAND_STAR_PLATINUM_BODY_L{tier}') for spell in base_stand_actions if spell != 'Target_UnarmedAttack')
       for tier in star_tier_actions
   ))
ok('Star Platinum combat actions are not only Lua standActions',
   all(action in sd for action in star_combat_actions)
   and all(f'UnlockSpell({action})' in stats_entry_block(char_stats, 'STAND_STAR_PLATINUM_BODY_L12') for action in star_combat_actions))

ok('Script Extender config exists', se_config.exists(), str(se_config))
cfg_ok = False
if se_cfg_text:
    try:
        cfg = json.loads(se_cfg_text)
        cfg_ok = 'Lua' in cfg.get('FeatureFlags', [])
    except Exception:
        cfg_ok = False
ok('Script Extender config enables Lua feature flag', cfg_ok)

# Level gates match
star_actions_match = re.search(r'TheStar\s*=\s*\{[\s\S]*?standActions\s*=\s*\{([\s\S]*?)\n\s*\},\n\s*passives', sd)
levels_lua = sorted(set(int(x) for x in re.findall(r'\[(\d+)\]\s*=\s*\{', star_actions_match.group(1) if star_actions_match else '')))
levels_star_prog = []
for m in re.finditer(r'<node id="Progression">([\s\S]*?)</node>', p):
    chunk = m.group(1)
    if 'value="TheStar"' in chunk:
        lv = re.search(r'Level" type="uint8" value="(\d+)"', chunk)
        if lv:
            levels_star_prog.append(int(lv.group(1)))
levels_star_prog = sorted(set(levels_star_prog))
expected_star_action_levels = sorted(set(levels_star_prog + [5]))
ok('TheStar action gates match subclass progression plus level 5 class note',
   levels_lua == expected_star_action_levels,
   f'lua={levels_lua} expected={expected_star_action_levels} prog={levels_star_prog}')

# Obsolete feat-first path not active
feat_file = root / 'Public/StandPrototype/Stats/Generated/Data/StandPrototype_Feats.txt'
ok('Obsolete feats file removed', not feat_file.exists())
text_blobs = []
text_by_path = {}
for path in root.rglob('*'):
    if path.is_file() and path.suffix.lower() in {'.md','.txt','.lsx','.lua','.sh','.py','.example','.env'}:
        if path.name == 'validate_static.py':
            continue
        try:
            text = path.read_text()
            text_blobs.append(text)
            text_by_path[path.relative_to(root).as_posix()] = text
        except Exception:
            pass
joined = '\n'.join(text_blobs)
ok('No active feat unlock references', 'Feat_StandUserBase' not in joined and 'Feat_Arcana_TheStar' not in joined)
stale_doc_patterns = [
    'stock underwear',
    'loincloth',
    'equip attempt',
    'Star Platinum receives stand combat actions at runtime',
    'runtime override skipped',
    'grantStandTierSpells',
    'BASE_Humans_Male_Strong',
    'EQP_Unarmed',
    'initialweaponset',
]
stale_doc_hits = [
    f'{path}: {pattern}'
    for path, text in text_by_path.items()
    if path.endswith(('.md', '.txt'))
    for pattern in stale_doc_patterns
    if pattern in text
]
ok('Docs do not describe removed fallback/runtime-grant architecture',
   not stale_doc_hits,
   '; '.join(stale_doc_hits[:8]))

# dist/.build_stage not source of truth
ok('Build script rebuilds and does not trust existing stage dir',
   ('prepare_stage_dir' in bs or 'rm -rf "$STAGE_DIR"' in bs) and 'cp -a "$MOD_ROOT/Public" "$STAGE_DIR/Public"' in bs)

# Install script should deploy packaged .pak, not source-folder symlink.
ok('Install script deploys .pak into BG3 Mods', '.pak' in ins and 'cp -f "$PAK_PATH" "$TARGET_PAK"' in ins and '--symlink' not in ins)

ok('Ability distribution preset linked to StandUser class UUID',
   'ClassUUID" type="guid" value="7a23b113-0a85-4f8f-86ca-7f88f5de9c61"' in ap)

# Runtime verification reminder for skill picker UX
warn(
    'Level 1 skill picker requires in-game UX verification',
    'Test: New Game -> StandUser -> verify exactly 2 skill picks are presented from the Stand User skill list.'
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
