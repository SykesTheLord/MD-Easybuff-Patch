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
- **Verify against the 2.0 dev source, not a Steam Workshop copy.** Both Workshop versions of MD
  are 2.0.0 as of the 2026-09-12 update - the release (`2777392649`, "Millennium Dawn: A Modern
  Day Mod") and the beta (`3374271790`, "Millennium Dawn: A Beta Test Mod") - while the dev
  source is 2.0.1, and Workshop content changes whenever Steam updates it. Before that update the
  release copy was 1.12.x, which lacks `add_new_org` and uses `add_relative_party_popularity`.
  The launcher's `mod/ugc_<id>.mod` pointer can lag behind the downloaded content (it still read
  1.12.2 after the update), so read `workshop/content/394360/<id>/descriptor.mod` for the real
  version. This mod targets 2.0 only.

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

## Scripted GUI

Two panels, each `.gui` paired with a same-named `common/scripted_guis/` file, each hosted by its
own decision category (`context_type = decision_category`, so no parent window):
- `zz_ebmd_input_gui` - the Value Setter, in `ebmd_systems_decision`.
- `zz_ebmd_buildings_gui` - off-map buildings, in `ebmd_buildings_decision`. That category has no
  decisions, so it needs `visible_when_empty = yes` or the engine hides it.

A category holds one `scripted_gui`, which is why the panels have separate categories.

**Off-map buildings have no state.** MD sums building counts per controlled state
(`industrial_complex_total`, `nuclear_reactors`, ...), so an off-map building is invisible to
MD's GDP, tax and workforce math. Only offer a type whose effect is engine-level or a country
modifier MD reads; state-local output (`local_resources_*`) is lost off-map.

**HOI4 has no scripted-GUI text input.** `editBoxType` exists in the engine but is wired only to
hardcoded systems (chat, unit renaming); scripted GUIs can bind nothing but `_click`,
`_click_enabled` and `_visible`. Stepping a staged value with buttons is the workaround, and is
what MD does for its own central bank and tax controls. Do not try to add a numeric field.

Two things that are easy to get wrong, both silent in-game:
- Button names in the `.gui` must match `<name>_click` handlers exactly, and `_click_enabled` /
  `_visible` triggers must name a real button. `package.sh` checks all three.
- A live readout needs the `dirty = <variable>` property plus a bump of that variable in every
  handler, or the text will not redraw. Live values come from `[?variable|format]` in
  localisation (`|2` = two decimals).

## Generated content

`common/scripted_effects/zz_ebmd_tech_generated.txt` is generated - never hand-edit it. HOI4
script cannot loop over technologies, so all 1395 of MD's dated techs are written out
explicitly, bucketed by `start_year` behind a `date` trigger.

Every `set_technology` block carries `popup = no` - without it the engine opens one
"technology researched" window per technology, which is unusable at this volume. It is a
per-block key, so one line covers the whole block.

Regenerate after any MD update: `python3 tools/gen_tech_effect.py`. `package.sh` refuses to
package a stale list. The same file holds `ebmd_research_microchip_composite_techs`, selected by
`CAT_microchips` / `CAT_composites` rather than date; the generator fails if those categories
disappear. Techs with no `start_year` are excluded from the date effects on purpose - they belong to a
specific country's focus tree, or are hidden special-project techs.

## Load order

`Millennium Dawn` → `+Easybuff` → this mod. MD declares `replace_path` for `events`,
`common/decisions`, `common/ideas`, `common/scripted_effects` and others, which discards those
directories from every **earlier**-loading mod. Anything loading before MD is erased.

## Verification

There is no test framework. Run `/validate` before calling work done — it checks brace balance,
resolves every effect call against MD 2.0, checks localisation coverage and idea pictures, and
verifies encodings. Static checks only; in-game confirmation is `TESTING.md`.

## Publishing

Headed for the Steam Workshop. `thumbnail.png` is generated by `python3 tools/gen_thumbnail.py`
- edit the script, never the PNG. `descriptor.mod` will need `remote_file_id` once the first
upload assigns one. Flag anything that would break a Workshop upload.

`descriptor.mod` and `+Easybuff-MD-Systems.mod` carry the same one-line `description=`. The
launcher's descriptor schema allows extra keys and preserves them, but nothing in the launcher or
the upload reads it, so it is **not** the Workshop page text - that is written on Steam. Keep it
a single quoted line with no double quotes, braces or the word "Beta" (the package step strips
"Beta" from the name line, and a stray one here would read as a leftover).
