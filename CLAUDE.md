# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This is a Hearts of Iron IV mod: a cheat patch exposing Millennium Dawn's economy, politics,
counter-terror and energy systems. It is plain Clausewitz script — no build, no tests, no
package manager. Correctness comes from verifying identifiers against the MD source.

## Reference sources (read-only)

| Path | What it is |
|---|---|
| `~/Projects/Millennium-Dawn` | MD **2.0 dev source** — the target. The authority for every effect, variable and modifier name. |
| `~/Projects/Easybuff/_Inkitmod/Easybuff` | Base mod whose UI conventions this patch mirrors. |

**Never edit either.** Everything this mod does lives in this folder and loads after both.

## Verifying MD identifiers

Never call an MD effect, variable or modifier without confirming it in the 2.0 source first:

```
grep -rE "^<name> = \{" ~/Projects/Millennium-Dawn/common/scripted_effects/
grep -rE "^\s*<name> = \{" ~/Projects/Millennium-Dawn/common/modifier_definitions/
```

Two traps, both hit during the initial build:

- **The published scripted-effects reference documents MD 1.12.x, not 2.0.** Its names for the
  budget effects, party popularity, the faction opinion input, and the energy build effects are
  all wrong for this target. When the docs and `common/` disagree, `common/` wins.
- **The installed Steam Workshop MD is 1.12.3b — a different codebase.** Do not verify against
  `~/.local/share/Steam/steamapps/workshop/content/394360/2777392649`. It lacks `add_new_org`
  and uses `add_relative_party_popularity`. This mod targets 2.0 only.

If an MD update renames something: re-verify against the 2.0 source and update the call. Do not
add version-branching shims or 1.12.x compatibility.

## The rule that drives the design

MD recomputes `gdp_total`, `gdp_per_capita`, `interest_rate` and the whole energy balance from
their inputs on every `ingame_update_setup` (weekly, and on any focus/decision/event). Writing
those variables directly lasts one tick.

So: **if MD recalculates a value, cheat it with a modifier (idea column); if MD stores it, cheat
it with an effect call (event option).** Inflation is the middle case — quarterly, so a direct
set holds ~3 months.

Always call MD's own effect rather than reimplementing it, so MD's clamps, tooltips and refresh
hooks still run. Convert "set to X" into the delta call MD exposes (see `ebmd_set_debt`).

## Conventions

- **Naming**: scripted effects/triggers `ebmd_*`; files `zz_ebmd_*` (sorts last in shared dirs);
  event namespace `ebmd`; decision category `ebmd_systems_decision`; idea category `zebmd_idea`.
  These must stay distinct from the separate `+++Easybuff - Millennium Dawn` patch so both can
  load together.
- **Encoding**: `.txt` is UTF-8 **without** BOM; `localisation/**.yml` is UTF-8 **with** BOM.
  Getting this backwards makes the game silently ignore the file.
- **Indentation**: tabs in script, opening brace on the same line. Localisation uses one leading
  space per key, plain `key: "value"` with no version numbers.
- **Idea categories**: declare our own. Redefining Easybuff's `zcheat_idea` in a later-loading
  file overrides rather than merges, silently deleting its slots.
- **Event option budget**: an event page fits **11 options at most**, including the Back/Close
  row. Easybuff's `interface/zeasybuffevent.gui` sizes the options grid 406px tall with 35px
  slots, and no Easybuff event exceeds 11. Anything beyond that is silently cut off with no
  error - split into a sub-page instead (the menu already nests, e.g. Economy -> `ebmd.13-.15`).
  Keep pages at 9 or fewer to leave room to grow.
- **Loop safety**: any `while_loop_effect` over an MD array needs a bounded counter guard — if an
  MD change makes the body a no-op, the loop hangs the game.

## Load order

`Millennium Dawn` → `+Easybuff` → this mod. MD declares `replace_path` for `events`,
`common/decisions`, `common/ideas`, `common/scripted_effects` and others, which discards those
directories from every **earlier**-loading mod. Anything loading before MD is erased.

## Verification

There is no test framework. Run `/validate` before calling work done — it checks brace balance,
resolves every effect call against MD 2.0, checks localisation coverage and idea pictures, and
verifies encodings. Static checks only; in-game confirmation is `TESTING.md`.

## Publishing

Headed for the Steam Workshop. `descriptor.mod` still needs a `picture`/thumbnail and will need
`remote_file_id` once uploaded. Flag anything that would break a Workshop upload.
