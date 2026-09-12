#!/usr/bin/env bash
# Install "+Easybuff - MD Systems" into a Hearts of Iron IV user data directory.
#
# HOI4 loads mods from the USER DATA directory, not the Steam game folder:
#   ~/.local/share/Paradox Interactive/Hearts of Iron IV
# That directory holds "mod/", where this script places the mod and its .mod pointer.
#
#   ./install.sh                          link into the default path (edits stay live)
#   ./install.sh -p /some/hoi4/userdir    link into a path you choose
#   ./install.sh --copy                   copy instead of symlink
#   ./install.sh --uninstall              remove it again
set -euo pipefail

MOD_DIR_NAME="MD-Easybuff-Patch"
MOD_FILE="+Easybuff-MD-Systems.mod"
DEFAULT_USERDIR="$HOME/.local/share/Paradox Interactive/Hearts of Iron IV"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERDIR=""
MODE="link"
ACTION="install"

die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
note() { printf '  %s\n' "$*"; }
ok() { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }

usage() {
	sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
	exit 0
}

while [ $# -gt 0 ]; do
	case "$1" in
		-p|--path) USERDIR="${2:-}"; shift 2 ;;
		-c|--copy) MODE="copy"; shift ;;
		-l|--link) MODE="link"; shift ;;
		-u|--uninstall) ACTION="uninstall"; shift ;;
		-h|--help) usage ;;
		-*) die "unknown option: $1 (try --help)" ;;
		*) USERDIR="$1"; shift ;;
	esac
done

# Source sanity: refuse to install something that isn't this mod.
[ -f "$SRC/descriptor.mod" ] && [ -f "$SRC/$MOD_FILE" ] \
	|| die "run this from the mod folder (no descriptor.mod / $MOD_FILE beside the script)"

# Resolve the target directory.
if [ -z "$USERDIR" ]; then
	printf 'HOI4 user data directory\n'
	note "default: $DEFAULT_USERDIR"
	printf 'Path (blank for default): '
	read -r reply || true
	USERDIR="${reply:-$DEFAULT_USERDIR}"
fi

USERDIR="${USERDIR%/}"
USERDIR="${USERDIR/#\~/$HOME}"

# Accept being handed the mod/ directory itself.
[ "$(basename "$USERDIR")" = "mod" ] && USERDIR="$(dirname "$USERDIR")"

[ -d "$USERDIR" ] || die "no such directory: $USERDIR"

# Catch the common mistake of pointing at the Steam game install.
if [ -f "$USERDIR/hoi4" ] || [ -f "$USERDIR/hoi4.exe" ]; then
	warn "that looks like the Steam game folder, not the user data folder."
	warn "mods belong in: $DEFAULT_USERDIR"
	die "re-run with the user data path"
fi

MODROOT="$USERDIR/mod"
DEST="$MODROOT/$MOD_DIR_NAME"
DESCRIPTOR="$MODROOT/$MOD_FILE"

if [ "$ACTION" = "uninstall" ]; then
	removed=0
	if [ -L "$DEST" ]; then rm -f "$DEST"; ok "removed link $DEST"; removed=1
	elif [ -d "$DEST" ]; then rm -rf "$DEST"; ok "removed folder $DEST"; removed=1; fi
	if [ -f "$DESCRIPTOR" ]; then rm -f "$DESCRIPTOR"; ok "removed $DESCRIPTOR"; removed=1; fi
	[ "$removed" -eq 0 ] && note "nothing installed at $MODROOT"
	exit 0
fi

mkdir -p "$MODROOT"

# Clear any previous install so copy/link modes can be swapped freely.
[ -L "$DEST" ] && rm -f "$DEST"
[ -d "$DEST" ] && rm -rf "$DEST"

if [ "$MODE" = "link" ]; then
	# Refuse to link a source that lives inside the target - it would nest into itself.
	case "$SRC/" in "$MODROOT"/*) die "source is already inside $MODROOT; use --copy or move the repo";; esac
	ln -s "$SRC" "$DEST"
	ok "linked $DEST -> $SRC"
	note "edits in the repo apply immediately; no reinstall needed"
else
	mkdir -p "$DEST"
	# Ship only what the game reads.
	for item in common events localisation descriptor.mod thumbnail.png; do
		[ -e "$SRC/$item" ] && cp -R "$SRC/$item" "$DEST/"
	done
	ok "copied mod files to $DEST"
fi

cp "$SRC/$MOD_FILE" "$DESCRIPTOR"
ok "installed descriptor $DESCRIPTOR"

# Verify the game will actually find content.
[ -d "$DEST/common" ] && [ -d "$DEST/events" ] \
	|| die "install looks incomplete - $DEST is missing common/ or events/"

printf '\n'
ok "installed"
note "Enable in the launcher, then set load order:"
note "  Millennium Dawn  ->  +Easybuff  ->  +Easybuff - MD Systems"
note "This mod must load LAST. Requires Millennium Dawn 2.0.x."
