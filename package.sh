#!/usr/bin/env bash
# Build a clean Steam Workshop package folder for "+Easybuff - MD Systems".
#
# Produces build/MD-Easybuff-Patch/ containing ONLY what the game reads --
# common/, events/, localisation/, descriptor.mod, thumbnail.png. The repo's
# docs, install scripts, .claude/ config and .git/ are deliberately left out:
# a Workshop upload should carry no build-side files.
#
# Validates before staging, because a broken brace or a missing BOM produces no
# error in-game -- it just silently loads nothing, and by then it is published.
#
#   ./package.sh              build the package folder
#   ./package.sh --zip        also produce a distributable archive
#   ./package.sh -o DIR       write somewhere other than build/
#   ./package.sh --clean      delete the build output and exit
set -euo pipefail

MOD_DIR_NAME="MD-Easybuff-Patch"
OUT_ROOT="build"
MAKE_ZIP=0
DO_CLEAN=0

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MD_SRC="${MD_SRC:-$HOME/Projects/Millennium-Dawn}"
VANILLA="${VANILLA:-$HOME/.local/share/Steam/steamapps/common/Hearts of Iron IV}"

# Only these are shipped. Add to this list when the mod gains a new content dir
# (gfx/, interface/, music/ ...), or the game will not see it.
CONTENT=(common events localisation descriptor.mod thumbnail.png)

red=$'\033[31m'; grn=$'\033[32m'; ylw=$'\033[33m'; bld=$'\033[1m'; rst=$'\033[0m'
die()   { printf '%serror:%s %s\n' "$red" "$rst" "$*" >&2; exit 1; }
ok()    { printf '%s✓%s %s\n' "$grn" "$rst" "$*"; }
note()  { printf '  %s\n' "$*"; }
head2() { printf '\n%s%s%s\n' "$bld" "$*" "$rst"; }

ERRORS=0
BLOCKERS=()
fail()    { printf '  %s✗%s %s\n' "$red" "$rst" "$*"; ERRORS=$((ERRORS+1)); }
blocker() { BLOCKERS+=("$1"); }

usage() { sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }

while [ $# -gt 0 ]; do
	case "$1" in
		-o|--output) OUT_ROOT="${2:?--output needs a directory}"; shift 2 ;;
		-z|--zip)    MAKE_ZIP=1; shift ;;
		--clean)     DO_CLEAN=1; shift ;;
		-h|--help)   usage ;;
		*)           die "unknown option: $1 (try --help)" ;;
	esac
done

cd "$SRC"
[ -f descriptor.mod ] || die "run this from the mod folder (no descriptor.mod beside the script)"

OUT_ROOT="${OUT_ROOT%/}"
STAGE="$OUT_ROOT/$MOD_DIR_NAME"

if [ "$DO_CLEAN" -eq 1 ]; then
	[ -d "$OUT_ROOT" ] && { rm -rf "$OUT_ROOT"; ok "removed $OUT_ROOT/"; } || note "nothing to clean at $OUT_ROOT/"
	exit 0
fi

# ---------------------------------------------------------------- validation
# Same checks as /validate. A package is the worst place to discover these.
head2 "Validating content"

for f in $(find common events -name "*.txt" 2>/dev/null) descriptor.mod; do
	o=$(tr -cd '{' < "$f" | wc -c); c=$(tr -cd '}' < "$f" | wc -c)
	[ "$o" != "$c" ] && fail "unbalanced braces in $f ($o open / $c close)"
done
[ "$ERRORS" -eq 0 ] && ok "brace balance"

if [ -d "$MD_SRC/common/scripted_effects" ]; then
	tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
	grep -rhoE "^[[:space:]]+[a-z_][a-z_0-9]* = yes" common events \
		| awk '{print $1}' | sort -u > "$tmp/calls"
	grep -rhoE "^[a-z_][a-z_0-9]* = \{" common/scripted_effects common/scripted_triggers \
		| sed 's/ = {//' | sort -u > "$tmp/ours"
	unresolved=0
	while read -r e; do
		case "$e" in always|is_major|is_triggered_only|is_ai|has_war|is_subject) continue;; esac
		grep -rqE "^$e = \{" "$MD_SRC/common/scripted_effects/" "$MD_SRC/common/scripted_triggers/" \
			|| { fail "calls an effect that does not exist in MD 2.0: $e"; unresolved=1; }
	done < <(comm -23 "$tmp/calls" "$tmp/ours")
	[ "$unresolved" -eq 0 ] && ok "every MD effect call resolves"
else
	printf '  %s!%s MD source not at %s - skipped effect resolution\n' "$ylw" "$rst" "$MD_SRC"
	note "set MD_SRC=/path/to/Millennium-Dawn to enable this check"
fi

encbad=0
while IFS= read -r f; do
	[ "$(head -c3 "$f" | xxd -p)" = "efbbbf" ] && { fail "$f has a UTF-8 BOM (script files must not)"; encbad=1; }
done < <(find common events -name "*.txt")
for f in localisation/english/*.yml; do
	[ "$(head -c3 "$f" | xxd -p)" != "efbbbf" ] && { fail "$f is missing its UTF-8 BOM"; encbad=1; }
done
[ "$encbad" -eq 0 ] && ok "encodings (no BOM on script, BOM on localisation)"

locmiss=0
tmp2=$(mktemp -d)
sed 's/\xEF\xBB\xBF//' localisation/english/*.yml | grep -oE "^ [A-Za-z0-9_.]+:" | tr -d ' :' | sort -u > "$tmp2/loc"
{ grep -oE "name = [A-Za-z0-9_.]+" events/*.txt | sed 's/.*name = //'
  grep -oE "(title|desc) = [A-Za-z0-9_.]+" events/*.txt | sed 's/.*= //'
} | sort -u | while read -r k; do grep -qx "$k" "$tmp2/loc" || echo "$k"; done > "$tmp2/missing"
if [ -s "$tmp2/missing" ]; then
	while read -r k; do fail "no localisation for $k"; done < "$tmp2/missing"
	locmiss=1
fi
rm -rf "$tmp2"
[ "$locmiss" -eq 0 ] && ok "localisation coverage"

[ "$ERRORS" -gt 0 ] && die "$ERRORS content problem(s) above - fix before packaging"

# ------------------------------------------------------- Workshop metadata
head2 "Checking Workshop metadata"

for key in name version supported_version tags; do
	grep -qE "^[[:space:]]*$key[[:space:]]*=" descriptor.mod || blocker "descriptor.mod has no '$key='"
done

if [ -f thumbnail.png ]; then
	bytes=$(stat -c%s thumbnail.png 2>/dev/null || stat -f%z thumbnail.png)
	dims=$(python3 -c "
import struct
d=open('thumbnail.png','rb').read(33)
w,h=struct.unpack('>II',d[16:24]); print(f'{w}x{h}')" 2>/dev/null || echo "unknown")
	ok "thumbnail.png present ($dims, $bytes bytes)"
	[ "$bytes" -gt 1048576 ] && blocker "thumbnail.png is over Steam's 1 MB limit"
else
	blocker "no thumbnail.png (Steam requires one; Millennium Dawn ships 500x500 PNG)"
fi

grep -qE '^[[:space:]]*picture[[:space:]]*=' descriptor.mod \
	|| blocker "descriptor.mod has no 'picture=' line pointing at the thumbnail"

grep -qE '^[[:space:]]*remote_file_id[[:space:]]*=' descriptor.mod \
	|| note "no remote_file_id yet - expected until the first upload assigns one"

[ "${#BLOCKERS[@]}" -eq 0 ] && ok "descriptor is upload-ready"

# ------------------------------------------------------------------ staging
head2 "Staging"

rm -rf "$STAGE"
mkdir -p "$STAGE"
for item in "${CONTENT[@]}"; do
	[ -e "$item" ] && cp -R "$item" "$STAGE/"
done
ok "staged to $STAGE/"

# The working copy is named "... Beta" so the launcher shows which build is
# installed locally. The published package drops that word: Steam should carry
# the release name. Only the STAGED descriptor is rewritten - the repo keeps Beta.
DEV_NAME=$(sed -n 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' descriptor.mod | head -1)
[ -n "$DEV_NAME" ] || die "could not read name= from descriptor.mod"
REL_NAME=$(printf '%s' "$DEV_NAME" | sed -E 's/\b[Bb][Ee][Tt][Aa]\b//g; s/[[:space:]]{2,}/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+-$//')

if [ -z "$REL_NAME" ]; then
	die "stripping 'Beta' from \"$DEV_NAME\" leaves an empty name - check descriptor.mod"
fi

if [ "$REL_NAME" != "$DEV_NAME" ]; then
	awk -v n="$REL_NAME" '
		!seen && /^[[:space:]]*name[[:space:]]*=/ { printf "name=\"%s\"\n", n; seen=1; next }
		{ print }
	' "$STAGE/descriptor.mod" > "$STAGE/descriptor.mod.tmp" \
		&& mv "$STAGE/descriptor.mod.tmp" "$STAGE/descriptor.mod"

	# Scoped to the name line: a dependency legitimately may contain "Beta"
	# (Millennium Dawn ships "A Beta Test Mod"), and stripping that would break it.
	grep -qiE '^[[:space:]]*name[[:space:]]*=.*beta' "$STAGE/descriptor.mod" \
		&& die "staged descriptor name still says beta"
	ok "release name: \"$DEV_NAME\" -> \"$REL_NAME\""
else
	note "name has no 'Beta' to strip - packaging as \"$DEV_NAME\""
fi

# Verify the staged copy rather than trusting cp: a package that lost its BOMs
# or picked up stray files looks fine until the game silently ignores it.
[ -d "$STAGE/common" ] && [ -d "$STAGE/events" ] || die "staging incomplete - missing common/ or events/"

while IFS= read -r f; do
	[ "$(head -c3 "$f" | xxd -p)" != "efbbbf" ] && die "staged $f lost its BOM"
done < <(find "$STAGE/localisation" -name "*.yml" 2>/dev/null)

stray=$(find "$STAGE" \( -name ".*" -o -name "*.md" -o -name "*.sh" -o -name "*.ps1" \) -print -quit)
[ -n "$stray" ] && die "stray non-game file staged: $stray"
ok "staged copy verified (encodings intact, no build-side files)"

# ---------------------------------------------------------------- archive
if [ "$MAKE_ZIP" -eq 1 ]; then
	head2 "Archiving"
	command -v zip >/dev/null || die "zip is not installed"
	ver=$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' descriptor.mod | head -1)
	zipname="$OUT_ROOT/${MOD_DIR_NAME}-${ver:-unversioned}.zip"
	rm -f "$zipname"
	( cd "$OUT_ROOT" && zip -rq "$(basename "$zipname")" "$MOD_DIR_NAME" )
	ok "wrote $zipname ($(stat -c%s "$zipname" 2>/dev/null || stat -f%z "$zipname") bytes)"
fi

# ----------------------------------------------------------------- summary
head2 "Package contents"
find "$STAGE" -type f | sed "s|^$STAGE/|  |" | sort
printf '\n'
note "$(find "$STAGE" -type f | wc -l) files, $(du -sh "$STAGE" | cut -f1)"

if [ "${#BLOCKERS[@]}" -gt 0 ]; then
	printf '\n%s%sNOT READY FOR WORKSHOP%s\n' "$bld" "$red" "$rst"
	for b in "${BLOCKERS[@]}"; do printf '  %s✗%s %s\n' "$red" "$rst" "$b"; done
	printf '\nThe folder is built and usable for local testing, but fix the above before uploading.\n'
	exit 0
fi

printf '\n'
ok "ready to upload"
note "Point the Paradox launcher at $STAGE/ to publish, or upload the zip manually."
