#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$MOD_ROOT/.env"

MOD_NAME="StandPrototype"
MOD_UUID="4dd59dfc-8cd2-4b85-a19d-8f74a89fd8ce"
MOD_VERSION64="36028797018963968"

PROFILE_DIR=""
MODSETTINGS_PATH=""

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

PROFILE_DIR="${BG3_PROFILE_DIR:-}"
if [[ -z "$PROFILE_DIR" ]]; then
  PROFILE_CANDIDATES=(
    "$HOME/.steam/steam/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios/Baldur's Gate 3/PlayerProfiles/Public"
    "$HOME/.local/share/Steam/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios/Baldur's Gate 3/PlayerProfiles/Public"
    "$HOME/.local/share/Larian Studios/Baldur's Gate 3/PlayerProfiles/Public"
  )
  for p in "${PROFILE_CANDIDATES[@]}"; do
    if [[ -d "$p" ]]; then
      PROFILE_DIR="$p"
      break
    fi
  done
fi

if [[ -z "$PROFILE_DIR" ]]; then
  PROFILE_DIR="$HOME/.local/share/Larian Studios/Baldur's Gate 3/PlayerProfiles/Public"
fi

MODSETTINGS_PATH="${BG3_MODSETTINGS_PATH:-}"
if [[ -z "$MODSETTINGS_PATH" ]]; then
  MODSETTINGS_PATH="$PROFILE_DIR/modsettings.lsx"
fi

if [[ ! -f "$MODSETTINGS_PATH" ]]; then
  echo "FATAL: modsettings.lsx not found at: $MODSETTINGS_PATH" >&2
  echo "Launch BG3 once first, then retry." >&2
  exit 1
fi

BACKUP_PATH="${MODSETTINGS_PATH}.bak.$(date +%Y%m%d_%H%M%S)"
cp "$MODSETTINGS_PATH" "$BACKUP_PATH"

python3 - "$MODSETTINGS_PATH" "$MOD_NAME" "$MOD_UUID" "$MOD_VERSION64" <<'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

path = Path(sys.argv[1])
mod_name = sys.argv[2]
mod_uuid = sys.argv[3]
mod_version64 = sys.argv[4]

tree = ET.parse(path)
root = tree.getroot()

def find_node_by_id(parent, node_id):
    for n in parent.iter("node"):
        if n.attrib.get("id") == node_id:
            return n
    return None

def ensure_children(node):
    children = node.find("children")
    if children is None:
        children = ET.SubElement(node, "children")
    return children

def attr_value(node, attr_id):
    for a in node.findall("attribute"):
        if a.attrib.get("id") == attr_id:
            return a.attrib.get("value")
    return None

root_node = find_node_by_id(root, "root")
if root_node is None:
    raise SystemExit("FATAL: Could not find root node in modsettings.lsx")
root_children = ensure_children(root_node)

mods_node = find_node_by_id(root, "Mods")
if mods_node is None:
    mods_node = ET.SubElement(root_children, "node", {"id": "Mods"})
mods_children = ensure_children(mods_node)

modorder_node = find_node_by_id(root, "ModOrder")
if modorder_node is None:
    modorder_node = ET.SubElement(root_children, "node", {"id": "ModOrder"})
modorder_children = ensure_children(modorder_node)

def has_module_uuid(node, uuid):
    for child in node.findall("node"):
        if child.attrib.get("id") != "Module":
            continue
        for attr in child.findall("attribute"):
            if attr.attrib.get("id") == "UUID" and attr.attrib.get("value") == uuid:
                return True
    return False

def has_shortdesc_uuid(node, uuid):
    for child in node.findall("node"):
        if child.attrib.get("id") != "ModuleShortDesc":
            continue
        if attr_value(child, "UUID") == uuid:
            return True
    return False

if not has_module_uuid(modorder_children, mod_uuid):
    mod_entry = ET.SubElement(modorder_children, "node", {"id": "Module"})
    ET.SubElement(mod_entry, "attribute", {
        "id": "UUID", "type": "FixedString", "value": mod_uuid
    })

if not has_shortdesc_uuid(mods_children, mod_uuid):
    short = ET.SubElement(mods_children, "node", {"id": "ModuleShortDesc"})
    ET.SubElement(short, "attribute", {"id": "Folder", "type": "LSString", "value": mod_name})
    ET.SubElement(short, "attribute", {"id": "MD5", "type": "LSString", "value": ""})
    ET.SubElement(short, "attribute", {"id": "Name", "type": "LSString", "value": mod_name})
    ET.SubElement(short, "attribute", {"id": "UUID", "type": "FixedString", "value": mod_uuid})
    ET.SubElement(short, "attribute", {"id": "Version64", "type": "int64", "value": mod_version64})

tree.write(path, encoding="UTF-8", xml_declaration=True)
print(f"Updated {path}")
PY

echo "Enabled $MOD_NAME in modsettings.lsx"
echo "Backup: $BACKUP_PATH"
echo "Path:   $MODSETTINGS_PATH"
