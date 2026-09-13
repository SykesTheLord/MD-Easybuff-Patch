# +Easybuff — MD Systems

A single-player cheat patch that exposes the **Millennium Dawn** simulation layers the generic
`+Easybuff` menu cannot reach: GDP, national debt, interest rate, corporate tax, corruption,
treasury, monetary expansion and inflation, internal political factions, foreign influence,
counter-terrorism and the power grid.

> Unofficial. Not affiliated with the Millennium Dawn or +Easybuff teams; MD balance patches
> change these variables often and may break this mod without warning.

## Install

HOI4 loads mods from your **user data** directory, not the Steam game folder:

| OS | Path |
|---|---|
| Linux | `~/.local/share/Paradox Interactive/Hearts of Iron IV` |
| Windows | `%USERPROFILE%\Documents\Paradox Interactive\Hearts of Iron IV` |

```bash
./install.sh                      # link into the default path
./install.sh -p /path/to/userdir  # or a path you choose
./install.sh --copy               # copy instead of link
./install.sh --uninstall
```

```powershell
.\install.ps1                     # link into the default path
.\install.ps1 -Path "D:\...\Hearts of Iron IV"
.\install.ps1 -Copy
.\install.ps1 -Uninstall
```

Both prompt for the path if you don't pass one, and refuse to run if you point them at the
Steam game folder by mistake.

**Linking is the default** — a symlink on Linux, a directory junction on Windows — so edits in
this repo apply to the game immediately with no reinstall. Use `--copy` / `-Copy` for a
standalone install that doesn't depend on this folder staying put. The Windows script verifies
the junction actually resolves and falls back to copying if it doesn't, which matters on
OneDrive-redirected Documents folders and non-NTFS drives.

Uninstalling removes the link, never the files it points at.

After installing, enable the mod in the launcher and set the load order below.

## Value Setter panel

The decision tab carries a small scripted GUI: step a staged value with `±0.01 / ±0.1 / ±1 / ±10`
buttons, watch it update live, then apply it as the inflation rate, corporate tax percentage or
central bank rate. It calls the same effects as the menu, so both routes behave identically.

This exists because **HOI4 offers scripted GUIs no text input** — `editBoxType` is engine-internal
and scripted GUIs can bind only clicks and visibility. Stepping a value is the closest available
equivalent, and is how Millennium Dawn drives its own rate controls.

## Off-map buildings panel

A second decision category, **Millennium Dawn - Off-Map Buildings**, uses the same stepper: set how
many buildings one click adds (`±1 / ±5 / ±10 / ±100`), then click a building type. Buildings are
added with the engine's `add_offsite_building`, so they need no slots and cannot be bombed or
captured.

Only eight types are offered, because off-map buildings have no state and Millennium Dawn counts
buildings state by state:

| Offered | Why it works off-map |
|---|---|
| Civilian / military factories, dockyards | engine production, not MD script |
| Nuclear reactors, fossil power plants | MD's energy model reads their country modifier |
| Synthetic refineries, agriculture districts, fuel silos | country-level fuel modifiers |

Left out because they would do nothing: microchip and composite plants and offices (state-local
output), renewables (MD reads a per-state variable), and enrichment facilities (gated on MD's
per-state count). Off-map factories add production but **no GDP or tax income**.

## Generated technology list

`common/scripted_effects/zz_ebmd_tech_generated.txt` is produced by
`python3 tools/gen_tech_effect.py` from Millennium Dawn's own tech tree — HOI4 script cannot
iterate technologies, so each of the 1395 dated techs is named explicitly and grouped by
`start_year` behind a date trigger. The same generator writes the microchip and composite option,
selected by MD's `CAT_microchips` / `CAT_composites` categories rather than by date. Every block carries `popup = no`, so granting hundreds of
technologies does not bury the screen in "technology researched" windows. Regenerate the list
after an MD update; `package.sh` refuses to build a stale one.

## Workshop cover image

`thumbnail.png` (500x500, matching Millennium Dawn's) is drawn by
`python3 tools/gen_thumbnail.py` rather than stored as an opaque binary — the wordmark is the
mod's own name, so a rename is a re-run instead of a hunt for the source file. `descriptor.mod`
and the launcher pointer both carry `picture="thumbnail.png"`, which is what the majority of
installed mods use; Steam needs the file under 1 MB and the generator fails if it isn't.

## Packaging for the Steam Workshop

```bash
./package.sh            # build build/MD-Easybuff-Patch/
./package.sh --zip      # also write build/MD-Easybuff-Patch-<version>.zip
./package.sh -o DIR     # output somewhere else
./package.sh --clean    # delete the output
```

The package contains only what the game reads — `common/`, `events/`, `localisation/`,
`interface/`, `descriptor.mod`, `thumbnail.png`. The README, install scripts, `tools/`,
`.claude/` config and `.git/` are left out.

It validates before staging and **refuses to package** on a brace mismatch, a wrong BOM, a
missing localisation key, or a call to an MD effect that doesn't exist in 2.0. All four are
mistakes that produce no in-game error — the mod just silently loads nothing — so they must not
reach a published upload. It then re-verifies the staged copy rather than trusting `cp`.

**The name loses "Beta" on the way out.** The working copy is named
`+Easybuff - MD Systems Beta`, so the launcher shows which build you have installed locally.
`package.sh` rewrites only the staged `descriptor.mod` to `+Easybuff - MD Systems` — the repo
keeps the Beta name. The strip is word-boundary matched and scoped to the `name=` line, so a
dependency that legitimately contains "Beta" (Millennium Dawn ships *A Beta Test Mod*) is left
alone. Drop "Beta" from `descriptor.mod` when you want the release name locally too.

Point the Paradox launcher at the built folder to publish.

## Load order

This mod must load **after both** of its dependencies:

```
Millennium Dawn: A Modern Day Mod
+Easybuff
+Easybuff — MD Systems        ← this mod, last
```

Millennium Dawn declares `replace_path` for `events`, `common/decisions`,
`common/decisions/categories`, `common/ideas`, `common/scripted_effects` and
`common/scripted_triggers`, among 74 paths. `replace_path` discards those directories from
vanilla **and from every mod that loads earlier**. So `+Easybuff` itself has to sit after
Millennium Dawn too — if it loads first, MD erases Easybuff's own decisions, ideas and events
and neither mod works. That constraint comes from MD and Easybuff, not from this patch.

## Compatibility

| | Supported |
|---|---|
| Millennium Dawn | **2.0.x only** |
| Hearts of Iron IV | 1.19.\* |
| +Easybuff | 1.18 |

**MD 1.12.x is not supported.** MD 2.0 renamed the party-popularity effect
(`add_relative_party_popularity` → `change_relative_party_popularity`) and rewrote
counter-terrorism around a terror-organisation array system that does not exist in 1.12.x, so
the faction, party and counter-terror options would fail there.

Easybuff still tags itself `supported_version="1.18.*"` while MD targets `1.19.*`. That is
Easybuff's lag; this patch follows MD.

### Running alongside `+++Easybuff - Millennium Dawn`

Supported, and **not** a dependency. This mod does not read, require, or assume anything from
that patch — none of its categories, variables or repair decisions. The two can be loaded
together because every identifier here is namespaced separately:

| | This mod |
|---|---|
| Decision category | `ebmd_systems_decision` — "Millennium Dawn — Economy & Politics" |
| Event namespace | `ebmd` |
| Idea category | `zebmd_idea` |
| File prefix | `zz_ebmd_*` |
| Effect / trigger prefix | `ebmd_*` |

It also declares its own idea category rather than adding slots to Easybuff's `zcheat_idea`,
because redefining that category in a later-loading file would override it and silently delete
Easybuff's own slots.

## Usage

Two entry points, matching Easybuff's own pattern:

- the **Millennium Dawn — Economy & Politics** decision tab → *Open MD Systems Cheat Menu*
- the national ideas view → the **MD Cheats** column → *Open MD Cheat Menu*

The tiered idea columns (economy, counter-terror, power grid) are selected directly in the
national ideas view and are free to swap at any time.

Everything is hidden for AI countries and hidden entirely unless Millennium Dawn is active.

## Things worth knowing before you use it

**Some values cannot be set permanently, and the mod says so rather than pretending.** MD
rebuilds GDP, GDP per capita, interest rate and the whole energy balance from their inputs on
every economy refresh — weekly, and immediately on any focus, decision or event. Writing those
variables directly lasts exactly until the next refresh. Where that applies, the menu offers
both the transient poke (useful for one-tick tests) and a persistent idea column that moves the
inputs instead. The GDP option shows a warning screen explaining this.

Inflation is the exception: it only recalculates quarterly, so a set value holds for up to
three months.

**The central bank rate cuts both ways.** Raising it lowers inflation next quarter but raises
your interest rate immediately, because MD feeds half the policy rate into the rate premium. It
will fight the interest-rate options.

**Setting debt directly bypasses MD's loan gating.** MD applies no hard debt ceiling anywhere —
debt is clamped only at zero, and a debt-to-GDP ratio above 200% is reachable in normal play.
What actually limits borrowing is the availability rules on MD's loan and bailout *decisions*.
Setting debt through this menu skips those rules entirely. That is the option most likely to
break, or to become an unintended exploit, when a future MD patch tightens borrowing.

**Treasury is never set below zero.** MD converts a negative treasury into fresh debt plus a
fee on the next weekly tick, so a negative target would silently manufacture debt and raise
your interest rate.

**The event-firing options are tied to the MD version.** The event IDs are verified against MD
2.0; re-check them after an MD update.

**Counter-terror has no documented ceiling**, so "maximum" is a large value chosen here, not a
cap MD defines. Spawning a terror organisation does nothing when MD's inactive pool is empty or
no Middle Eastern country holds a state for the headquarters.

## Testing

[TESTING.md](TESTING.md) has a per-option checklist: the exact in-game step that confirms each
cheat applied, including the cases where the expected result is that a value *drifts back*.

## Repair decisions

If a value ends up out of range — through a bug, a mid-test edit, or the console — each system
has a repair decision that restores **Millennium Dawn's own bounds**, not bounds invented here,
and refreshes the affected panels. No save restart needed.

## Loading without Millennium Dawn

Every decision, idea and menu entry is gated, so nothing can execute. HOI4 will still log
unknown-effect lines to `error.log` at parse time, because the MD effects this mod calls do not
exist. That is expected and harmless; the declared dependencies mean it should not arise in
normal use.
