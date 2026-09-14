#!/usr/bin/env bash
# Uninstall the local (Beta) install of "+Easybuff - MD Systems" from a Hearts of Iron IV
# user data directory - what install.sh put there, and nothing else.
#
#   ./uninstall.sh                          remove from the default path
#   ./uninstall.sh -p /some/hoi4/userdir    remove from a path you choose
#   ./uninstall.sh --dry-run                show what would be removed, change nothing
#   ./uninstall.sh --force                  remove a folder even if it does not look like this mod
#
# Removes:
#   mod/MD-Easybuff-Patch          the link (never the repo it points at) or copied folder
#   mod/+Easybuff-MD-Systems.mod   the launcher pointer
#   its entry in dlc_load.json     the game's enabled-mods list (backed up first)
# A Steam Workshop subscription is never touched: those are mod/ugc_<id>.mod.
set -euo pipefail

MOD_DIR_NAME="MD-Easybuff-Patch"
MOD_FILE="+Easybuff-MD-Systems.mod"
MOD_NAME_RE='^[[:space:]]*name[[:space:]]*=[[:space:]]*"\+Easybuff - MD Systems( Beta)?"'
DEFAULT_USERDIR="$HOME/.local/share/Paradox Interactive/Hearts of Iron IV"

USERDIR=""
DRY=0
FORCE=0

die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
note() { printf '  %s\n' "$*"; }
ok() { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
act() { if [ "$DRY" -eq 1 ]; then note "would $*"; else "${@:2}"; fi; }

usage() {
	sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
	exit 0
}

while [ $# -gt 0 ]; do
	case "$1" in
		-p|--path) USERDIR="${2:-}"; shift 2 ;;
		-n|--dry-run) DRY=1; shift ;;
		-f|--force) FORCE=1; shift ;;
		-h|--help) usage ;;
		-*) die "unknown option: $1 (try --help)" ;;
		*) USERDIR="$1"; shift ;;
	esac
done

if [ -z "$USERDIR" ]; then
	printf 'HOI4 user data directory\n'
	note "default: $DEFAULT_USERDIR"
	printf 'Path (blank for default): '
	read -r reply || true
	USERDIR="${reply:-$DEFAULT_USERDIR}"
fi

USERDIR="${USERDIR%/}"
USERDIR="${USERDIR/#\~/$HOME}"
[ "$(basename "$USERDIR")" = "mod" ] && USERDIR="$(dirname "$USERDIR")"
[ -d "$USERDIR" ] || die "no such directory: $USERDIR"

if [ -f "$USERDIR/hoi4" ] || [ -f "$USERDIR/hoi4.exe" ]; then
	warn "that looks like the Steam game folder, not the user data folder."
	warn "the local install lives in: $DEFAULT_USERDIR"
	die "re-run with the user data path"
fi

MODROOT="$USERDIR/mod"
DEST="$MODROOT/$MOD_DIR_NAME"
POINTER="$MODROOT/$MOD_FILE"
DLC_LOAD="$USERDIR/dlc_load.json"
ENTRY="mod/$MOD_FILE"

[ "$DRY" -eq 1 ] && note "dry run - nothing will be changed"
removed=0

# 1. The mod itself. A link is only unlinked; a real folder must identify itself as this mod.
if [ -L "$DEST" ]; then
	act "remove link $DEST" rm -f "$DEST"
	[ "$DRY" -eq 1 ] || ok "removed link $DEST (its target is untouched)"
	removed=1
elif [ -d "$DEST" ]; then
	if [ "$FORCE" -eq 1 ] || { [ -f "$DEST/descriptor.mod" ] && grep -qE "$MOD_NAME_RE" "$DEST/descriptor.mod"; }; then
		act "remove folder $DEST" rm -rf "$DEST"
		[ "$DRY" -eq 1 ] || ok "removed folder $DEST"
		removed=1
	else
		die "$DEST exists but its descriptor.mod is not +Easybuff - MD Systems; refusing to delete it (use --force if you are sure)"
	fi
fi

# 2. The launcher pointer - only if it points at this mod's folder.
if [ -f "$POINTER" ]; then
	if [ "$FORCE" -eq 1 ] || grep -qE "^[[:space:]]*path[[:space:]]*=[[:space:]]*\"mod/$MOD_DIR_NAME\"" "$POINTER"; then
		act "remove $POINTER" rm -f "$POINTER"
		[ "$DRY" -eq 1 ] || ok "removed $POINTER"
		removed=1
	else
		die "$POINTER does not point at mod/$MOD_DIR_NAME; refusing to delete it (use --force if you are sure)"
	fi
fi

# 3. The enabled-mods list. Left in place, the game keeps asking for a mod that is gone.
#    The launcher's own database is not edited; it drops the entry when it next rescans.
if [ -f "$DLC_LOAD" ] && grep -qF "\"$ENTRY\"" "$DLC_LOAD"; then
	if [ "$DRY" -eq 1 ]; then
		note "would remove \"$ENTRY\" from $DLC_LOAD"
	else
		cp "$DLC_LOAD" "$DLC_LOAD.bak"
		# The entry is one quoted string in a JSON array; drop it with whichever comma joined it.
		esc=$(printf '%s' "$ENTRY" | sed 's/[.+/]/\\&/g')
		sed -i.tmp -E "s/\"$esc\",//; s/,\"$esc\"//; s/\"$esc\"//" "$DLC_LOAD" && rm -f "$DLC_LOAD.tmp"
		if grep -qF "\"$ENTRY\"" "$DLC_LOAD"; then
			cp "$DLC_LOAD.bak" "$DLC_LOAD"
			warn "could not remove the entry from $DLC_LOAD - left unchanged; disable the mod in the launcher instead"
		else
			ok "removed it from the enabled mods in $DLC_LOAD (backup: dlc_load.json.bak)"
		fi
	fi
	removed=1
fi

if [ "$removed" -eq 0 ]; then
	note "nothing installed at $MODROOT"
elif [ "$DRY" -eq 0 ]; then
	printf '\n'
	ok "uninstalled"
	note "If the launcher still lists the mod, restart the launcher so it rescans."
fi
