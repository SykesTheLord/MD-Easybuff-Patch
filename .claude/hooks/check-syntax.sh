#!/usr/bin/env bash
# PostToolUse hook: sanity-check an edited HOI4 mod file.
#
# Catches the two failure modes that produce NO error in-game, just silently
# broken content: an unbalanced brace (breaks Clausewitz parsing) and a wrong
# BOM (script must have none; localisation must have one).
#
# Reads the hook JSON payload on stdin. Always exits 0 - this reports, never blocks.

f=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)
[ -z "$f" ] && exit 0
[ -f "$f" ] || exit 0

problems=""

add() { problems="${problems:+$problems; }$1"; }

has_bom() { [ "$(head -c3 "$f" | xxd -p 2>/dev/null)" = "efbbbf" ]; }

case "$f" in
	*/localisation/*.yml)
		has_bom || add "missing UTF-8 BOM (the game silently ignores localisation without one)"
		;;
	*.txt|*.mod)
		o=$(tr -cd '{' < "$f" | wc -c)
		c=$(tr -cd '}' < "$f" | wc -c)
		[ "$o" != "$c" ] && add "unbalanced braces: $o open vs $c close"
		has_bom && add "has a UTF-8 BOM (script files must not)"
		;;
	*)
		exit 0
		;;
esac

[ -z "$problems" ] && exit 0

msg="HOI4 check failed for ${f##*/}: $problems"
jq -n --arg m "$msg" '{
	systemMessage: $m,
	hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: $m }
}'
exit 0
