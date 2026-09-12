---
name: validate
description: Static validation sweep for this HOI4 mod - brace balance, MD 2.0 effect resolution, localisation coverage, idea picture resolution, and file encodings. Use before declaring work done, after editing any script or localisation file, and before any Workshop upload.
---

Run every check below from the mod root. Report results as a short table; for any failure, name
the file and the offending identifier, then fix it.

These are static checks. They cannot confirm in-game behaviour — `TESTING.md` covers that.

## Setup

```bash
cd /home/jacob/Projects/MD-Easybuff-Patch
MD=~/Projects/Millennium-Dawn
VANILLA="/home/jacob/.local/share/Steam/steamapps/common/Hearts of Iron IV"
mkdir -p /tmp/ebmd-validate
```

## 1. Brace balance

A mismatch breaks Clausewitz parsing with no error until load.

```bash
for f in $(find . -name "*.txt" -o -name "*.mod"); do
  o=$(tr -cd '{' < "$f" | wc -c); c=$(tr -cd '}' < "$f" | wc -c)
  [ "$o" != "$c" ] && echo "MISMATCH $f: $o open / $c close"
done; echo "braces ok"
```

## 2. Every effect and trigger call resolves

The highest-value check. Catches calls to MD effects that don't exist in 2.0 — including names
taken from MD's published docs, which describe 1.12.x.

```bash
grep -rhoE "^[[:space:]]+[a-z_][a-z_0-9]* = yes" common events \
  | awk '{print $1}' | sort -u > /tmp/ebmd-validate/calls.txt
grep -rhoE "^[a-z_][a-z_0-9]* = \{" common/scripted_effects common/scripted_triggers \
  | sed 's/ = {//' | sort -u > /tmp/ebmd-validate/ours.txt
comm -23 /tmp/ebmd-validate/calls.txt /tmp/ebmd-validate/ours.txt | while read -r e; do
  case "$e" in always|is_major|is_triggered_only|is_ai|has_war|is_subject) continue;; esac
  grep -rqE "^$e = \{" "$MD/common/scripted_effects/" "$MD/common/scripted_triggers/" \
    || echo "  UNRESOLVED: $e"
done; echo "calls ok"
```

The `case` list skips vanilla triggers, which live in the engine rather than MD script. Add to it
only when a name is genuinely vanilla — never to silence a real miss.

## 3. Modifier names resolve

```bash
awk '/modifier = \{/{f=1;next} /^\t\t\t\}/{f=0} f' common/ideas/*.txt \
  | grep -oE "^[[:space:]]*[a-z_][a-z_0-9]* =" | tr -d ' =' | sort -u \
  | while read -r m; do
      grep -rqE "^\s*$m = \{" "$MD/common/modifier_definitions/" \
        || echo "  CHECK (not MD-custom, confirm vanilla): $m"
    done; echo "modifiers ok"
```

Anything reported here is either a typo or a genuine vanilla modifier — confirm which before
dismissing it.

## 4. Localisation coverage

```bash
sed 's/\xEF\xBB\xBF//' localisation/english/*.yml \
  | grep -oE "^ [A-Za-z0-9_.]+:" | tr -d ' :' | sort -u > /tmp/ebmd-validate/loc.txt
{ grep -oE "name = [A-Za-z0-9_.]+" events/*.txt | sed 's/.*name = //'
  grep -oE "(title|desc) = [A-Za-z0-9_.]+" events/*.txt | sed 's/.*= //'
} | sort -u | while read -r k; do
  grep -qx "$k" /tmp/ebmd-validate/loc.txt || echo "  MISSING LOC: $k"
done
{ grep -oE "^\t[a-z_][a-z_0-9]* = \{" common/decisions/zz_ebmd_decisions.txt | tr -d '\t' | sed 's/ = {//'
  grep -oE "^[a-z_][a-z_0-9]* = \{" common/decisions/categories/*.txt | sed 's/ = {//'
  grep -oE "^\t\t[a-z_][a-z_0-9]* = \{" common/ideas/*.txt | sed 's/.*\t//' | sed 's/ = {//'
  grep -oE "slot = [a-z_]+" common/idea_tags/*.txt | sed 's/.*slot = //'
  grep -oE "^\t[a-z_][a-z_0-9]* = \{" common/idea_tags/*.txt | sed 's/.*\t//' | sed 's/ = {//'
} | sort -u | while read -r k; do
  grep -qx "$k" /tmp/ebmd-validate/loc.txt || echo "  MISSING LOC: $k"
done; echo "loc ok"
```

## 5. Idea pictures resolve

An invalid `picture` renders as a missing texture with no error.

```bash
grep -rhoE "picture = [a-z_0-9]+" common/ideas/*.txt | sed 's/picture = //' | sort -u \
  | while read -r p; do
      grep -rqs "GFX_idea_$p" "$MD/interface/" "$VANILLA/interface/" \
        || echo "  BAD PICTURE: $p"
    done; echo "pictures ok"
```

## 6. Encodings

`.txt` must have no BOM; localisation `.yml` must have one. Backwards either way and the game
silently ignores the file.

```bash
for f in $(find . -name "*.txt"); do
  [ "$(head -c3 "$f" | xxd -p)" = "efbbbf" ] && echo "  BAD BOM: $f"
done
for f in localisation/english/*.yml; do
  [ "$(head -c3 "$f" | xxd -p)" != "efbbbf" ] && echo "  MISSING BOM: $f"
done; echo "encodings ok"
```

To add a BOM: `printf '\xEF\xBB\xBF' > f.tmp && cat f >> f.tmp && mv f.tmp f`

Note: `grep` for the BOM byte pattern gives false negatives — always compare with `xxd -p`.

## 7. Workshop readiness (only before an upload)

```bash
grep -qE '^picture=' descriptor.mod || echo "  descriptor.mod has no picture/thumbnail"
grep -qE '^remote_file_id=' descriptor.mod || echo "  no remote_file_id (expected until first upload)"
ls thumbnail.png 2>/dev/null || echo "  no thumbnail.png present"
```
