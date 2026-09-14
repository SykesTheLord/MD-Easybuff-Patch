# +Easybuff — MD Systems

A single-player cheat patch that exposes the **Millennium Dawn** simulation layers the generic
`+Easybuff` menu cannot reach: debt, treasury, tax, corruption, GDP, workforce, money supply and
inflation; internal factions, foreign influence, the ruling party and party popularity;
counter-terrorism; the power grid and energy buildings; off-map buildings; and technology.

> Unofficial. Not affiliated with the Millennium Dawn or +Easybuff teams; MD balance patches
> change these variables often and may break this mod without warning.

**Contents:** [Install](#install) · [Load order](#load-order) · [Compatibility](#compatibility) ·
[Opening the cheats](#opening-the-cheats) · [Cheat menu](#cheat-menu) ·
[Value Setter panel](#value-setter-panel) · [Off-map buildings panel](#off-map-buildings-panel) ·
[National idea columns](#national-idea-columns) · [Repair decisions](#repair-decisions) ·
[Things worth knowing](#things-worth-knowing-before-you-use-it) · [Development](#development)

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

### Uninstall

```bash
./uninstall.sh                      # remove from the default path
./uninstall.sh -p /path/to/userdir  # or a path you choose
./uninstall.sh --dry-run            # list what would be removed, change nothing
```

```powershell
.\uninstall.ps1
.\uninstall.ps1 -Path "D:\...\Hearts of Iron IV"
.\uninstall.ps1 -DryRun
```

This removes the local (Beta) install and nothing else:

| Removed | Notes |
|---|---|
| `mod/MD-Easybuff-Patch` | a link is only unlinked — the repo it points at is never touched; a copied folder is deleted only if its `descriptor.mod` names this mod |
| `mod/+Easybuff-MD-Systems.mod` | the launcher pointer, deleted only if it points at `mod/MD-Easybuff-Patch` |
| the entry in `dlc_load.json` | the game's enabled-mods list, so it stops asking for a mod that is gone; backed up to `dlc_load.json.bak` first |

A Steam Workshop subscription of this mod is safe: Workshop copies live in `mod/ugc_<id>.mod`
and are never matched. If something at those paths does not identify itself as this mod, the
script stops rather than deleting it; `--force` / `-Force` overrides that. The launcher's own
database is not edited — restart the launcher if it still lists the mod.

`./install.sh --uninstall` and `.\install.ps1 -Uninstall` still work; they run these scripts.

After installing, enable the mod in the launcher and set the load order below.

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
| +Easybuff | 1.19 (the current Workshop version) |

**Use Millennium Dawn's main Workshop release.** This mod depends on *Millennium Dawn: A Modern Day
Mod* (Workshop item 2777392649), which is 2.0 as of its September 2026 update. Millennium Dawn's
beta, *Millennium Dawn: A Beta Test Mod* (3374271790), is also 2.0, so the cheats should work with it (untested), but
the launcher matches dependencies by exact name, so with only the beta enabled it reports this mod
as missing a dependency. That warning is expected in that setup. Both names cannot be listed: the
launcher treats every listed dependency as required, so anyone without both would get the warning
instead.

**MD 1.12.x is not supported.** MD 2.0 renamed the party-popularity effect
(`add_relative_party_popularity` → `change_relative_party_popularity`) and rewrote
counter-terrorism around a terror-organisation array system that does not exist in 1.12.x, so
the faction, party and counter-terror options would fail there.

Easybuff 1.19 targets `1.19.*`, the same game version as Millennium Dawn. Its 1.19 update changed
only its version number; the menus, idea category and event window this patch mirrors are
unchanged from 1.18.

### Running alongside `+++Easybuff - Millennium Dawn`

Supported, and **not** a dependency. This mod does not read, require, or assume anything from
that patch — none of its categories, variables or repair decisions. The two can be loaded
together because every identifier here is namespaced separately:

| | This mod |
|---|---|
| Decision categories | `ebmd_systems_decision`, `ebmd_buildings_decision` |
| Event namespace | `ebmd` |
| Idea category | `zebmd_idea` |
| File prefix | `zz_ebmd_*` |
| Effect / trigger prefix | `ebmd_*` |

It also declares its own idea category rather than adding slots to Easybuff's `zcheat_idea`,
because redefining that category in a later-loading file would override it and silently delete
Easybuff's own slots.

## Opening the cheats

Everything is hidden for AI countries, and hidden entirely unless Millennium Dawn is active.

| Where | What is there |
|---|---|
| Decision tab **Millennium Dawn - Economy & Politics** | *Open MD Systems Cheat Menu*, the four [repair decisions](#repair-decisions), and the [Value Setter panel](#value-setter-panel) |
| Decision tab **Millennium Dawn - Off-Map Buildings** | the [off-map buildings panel](#off-map-buildings-panel) |
| National ideas view → **MD Cheats - Economy & Politics** | the **Open MD Cheat Menu** column (pick *Open MD Systems Cheat Menu*), plus the [economy, counter-terror and energy columns](#national-idea-columns) |

## Cheat menu

The menu is a chain of event pages, in the same style as Easybuff's own. **Clicking an option
applies it and reopens the same page**, so an option can be used repeatedly; *Back* steps up one
level and *Close* on the main page exits.

```
Main menu
├─ Economy
│   ├─ Debt & Interest Rate
│   ├─ Treasury & Costs
│   ├─ Tax & Corruption
│   ├─ GDP
│   ├─ Workforce & Population
│   ├─ Monetary Expansion & Printing
│   └─ Inflation & Central Bank
├─ Politics
│   ├─ Internal Factions & Parties
│   │   └─ Individual Factions
│   ├─ Foreign Influence
│   ├─ Fire / Suppress Events
│   └─ Ruling Party
│       └─ Pro-Western · Emerging · Salafist · Non-Aligned · Nationalist parties
├─ Counter-Terrorism
├─ Power Grid
│   └─ Power Construction
├─ Technology
└─ Repair Variables
```

### Economy

**Debt & Interest Rate**

| Option | What it does |
|---|---|
| Wipe debt (set to 0) | Sets debt to 0 through MD's own debt effect, then refreshes the economy. With no debt, MD's interest calculation drops to its floor. |
| Set debt to 100 | Sets debt to exactly 100. |
| Force interest rate above 15% | Sets debt to 1.6× GDP. MD derives the rate from the debt-to-GDP ratio, so this crosses the 15% threshold where MD's high-interest penalties apply and the default-on-debts decision becomes available. |
| Force interest rate above 25% | Sets debt to 2.6× GDP — past 25%, the point at which the AI is willing to default. |

MD recalculates the interest rate from debt and GDP, so it cannot be set directly; these options
move debt and let MD's own thresholds apply.

**Treasury & Costs**

| Option | What it does |
|---|---|
| Set treasury to 1,000 / 100,000 | Sets the treasury to that value. |
| Toggle: all MD scripted costs free | Turns MD's own `MD_skip_treasury_cost` flag on or off. While on, scripted treasury charges (decisions, construction, projects) cost nothing. |

**Tax & Corruption**

| Option | What it does |
|---|---|
| Set corporate tax to 0% / 50% | Sets the corporate tax rate. 50% is MD's maximum; MD also unlocks the rate if it was frozen. |
| Corruption to minimum / maximum | Steps MD's corruption ladder all the way down or up, using MD's own corruption effects. |

**GDP**

Opens with a warning page: MD rebuilds GDP from factories, offices, agriculture, power and
resources on every economy refresh, so a hand-set GDP only lasts until then.

| Option | What it does |
|---|---|
| Transient: double GDP / multiply by 10 / halve | Scales GDP and GDP per capita immediately. Lasts until the next economy refresh — useful only for one-tick tests. |
| Persistent: add the Lv4 MD Economy idea | Adds the Lv4 [economy idea](#national-idea-columns), which raises the inputs GDP is built from. |
| Persistent: roughly double productivity | Adds 1000 productivity to every controlled state through MD's own productivity effect — about double a typical state. |

**Workforce & Population**

| Option | What it does |
|---|---|
| Staff every factory | Adds population where workers are short (see below). Does nothing if unemployment is already 2% or more. |

MD pools workers nationally: about 60% of the population is the workforce, and sectors hire in a
fixed order (resources, agriculture, power plants, military factories, dockyards, civilian
factories, offices, resource plants). When the pool runs out, the sectors at the back run
under-staffed and lose output. This option adds population to the states with factories, offices
and plants — in proportion to how many each has — re-running MD's economy calculation after each
step, and stops once 2–5% unemployment is left over, below the 6% where MD's high-unemployment
penalties begin. The new people are real: they add manpower and raise healthcare and bureaucracy
costs. It can re-run MD's economy calculation up to about 27 times in one click, so a brief hitch
on large countries is normal.

**Monetary Expansion & Printing**

| Option | What it does |
|---|---|
| Grant monetary expansion (180 days / permanent) | Gives MD's monetary expansion idea (extra seigniorage income) **without** its normal price: no currency strength loss and no cooldown. |
| Remove monetary expansion | Removes that idea. |
| Print 500 / 5,000 | Adds that much treasury with none of printing's side effects: no political power cost, no inflation carried into next quarter, no recently-printed flag. |
| Clear monetary cooldowns | Clears MD's expansion and austerity cooldowns and the recently-printed flag, so MD's own buttons can be used again. |

**Inflation & Central Bank**

| Option | What it does |
|---|---|
| Set inflation to 0% / 2% / 25% | Sets the inflation rate, cancels any queued money-printing inflation, and recalculates inflation's knock-on effects straight away. MD recalculates inflation quarterly, so the value holds up to three months. |
| Set central bank rate to 15% / 0% | Sets MD's policy rate. A higher rate lowers inflation over the next quarter **but raises your interest rate** — see [things worth knowing](#things-worth-knowing-before-you-use-it). |

### Politics

**Internal Factions & Parties**

| Option | What it does |
|---|---|
| Set every faction to 100 | MD's own debug effect: every internal faction at maximum opinion. |
| All factions +25 / -25 | Shifts every faction's opinion. MD clamps opinions to 0–100. |
| Individual factions... | A page with ±50 for Oligarchs and The Military, and +50 for Labour Unions, Intelligence Community, The Clergy and Defense Industry. |
| Ruling party popularity +50% | Raises the ruling party's popularity through MD's own popularity effect. |

A faction your country does not have is silently skipped — that is MD's behaviour, not a failure.

**Foreign Influence**

| Option | What it does |
|---|---|
| Max / +25% influence over every neighbour | Adds your influence in every bordering country. |
| Max / +25% influence over every major power | The same for every major power. |
| +100% of my own domestic influence | Raises your domestic share at home. |
| Clear all foreign influence over me | Resets your country to 100% domestic influence. |

MD caps influence at 100% across all influencers in a country and redistributes the rest, so
these cannot break its totals. There is no single-country picker — Easybuff's menu has no target
selection — so influence is applied in groups.

**Fire / Suppress Events**

| Option | What it does |
|---|---|
| Fire: internal faction demand / protest revolt / corruption roll / terror attack / international terror escalation | Fires that MD event immediately; this page reopens behind it so you can fire another. |
| Suppress: auto-decline corruption events | Sets MD's own flag that auto-declines corruption events. |
| Allow corruption events again | Clears it, plus the recent-roll flag. |
| Clear pending protest revolt | Clears MD's pending-revolt flag. |

These are for testing event chains. The event IDs are checked against MD 2.0 and may change
with an MD update.

**Ruling Party**

Each page shows which party is currently in power.

| Option | What it does |
|---|---|
| Put the largest party in power | Installs whichever party is most popular right now, even if it already governs or is a coalition partner. Popularity is left unchanged. |
| Pro-Western / Emerging / Salafist / Non-Aligned / Nationalist parties | A page per outlook listing its parties by **this country's own party names**, with MD's generic name alongside. Picking one puts it in power. |

Picking a party works like Millennium Dawn's own cheat decisions: the party takes the government
and gains **+50% popularity** so it is not voted straight back out, and the coalition is cleared.
One deliberate difference: your elections setting is kept, where MD's version always turns
elections back on. A banned party can still be installed, but MD's ban effects stay in place.

| Outlook page | Parties (MD's generic names) |
|---|---|
| Pro-Western | Pro-Western Autocrat, Conservatism, Liberalism, Social Democrat |
| Emerging | Communist, Left-Wing, Reactionary, Autocracy, Moderate Shiite Revolutionary, Shiite Revolutionary |
| Salafist | Kingdom, Caliphate |
| Non-Aligned | Moderate Islamist, Autocracy, Conservative, Oligarchs, Libertarian, Green, Social Democrat, Communism |
| Nationalist | Populism, Fascism, Military Junta, Monarchist |

To set a party's popularity to an exact percentage instead, use the
[Value Setter panel](#value-setter-panel).

### Counter-Terrorism

| Option | What it does |
|---|---|
| Set counter-terror capability to maximum | Sets home defence and base detection to 500 and recalculates MD's threat detection. MD defines no ceiling, so 500 is a large value chosen here. |
| Zero counter-terror capability | Sets both to 0. |
| Add the Insane / Blind Counter-Terror idea | Adds that [counter-terror idea](#national-idea-columns) — persistent, unlike the direct values above. |
| Spawn one / three terror organisations | Creates organisations through MD's own spawn effect. Does nothing when MD's inactive pool is empty or no Middle Eastern country holds a state for the headquarters. |
| Remove every active terror organisation | Removes them one by one through MD's own removal effect, which keeps every country's intelligence records consistent. |

### Power Grid

| Option | What it does |
|---|---|
| Add the Lv3 / Insane Power Grid idea | Adds that [power grid idea](#national-idea-columns). MD rebuilds generation and consumption every recalculation, so the grid is changed through modifiers rather than by writing totals. |
| Power Construction... | Opens the construction page below. |
| Recalculate the grid now | Forces MD's energy calculation instead of waiting for the next tick. |

**Power Construction** — all free, recalculated into the grid straight away:

| Option | What it does |
|---|---|
| Build 5 / 25 battery parks | Adds battery park storage through MD's own free-build path. |
| Add hydroelectric capacity to a random state | Adds hydroelectric generation and storage to one of your states. |
| Build 3 nuclear reactors | Builds three reactors in your states. |
| Renewable Energy Infrastructure (every state) | One level in every state you own, skipping states at the 20-level cap. Output follows each state's renewable roll, which MD re-rolls monthly. |
| Nuclear Enrichment Facility (every state) | One facility in every state you own that lacks one, plus what MD's nuclear energy project does on completion: grants Nuclear Technology, registers you as an enrichment country, raises the reactor fuel stockpile to at least 300, and **switches reactor fuel production on** — without that the facilities produce nothing. |

### Technology

| Option | What it does |
|---|---|
| Research everything available by the current date | Every one of MD's 1,395 dated technologies whose start year has been reached; future tiers stay locked. |
| Research every dated technology | All 1,395, including future tiers. |
| Research all microchip and composite technologies | All 38 microchip and composite technologies, whatever their date, without MD's microchip or composite special projects. |
| Microchip Plant (every state, +1 building slot each) | One microchip plant **and** one extra building slot in every state you own, so no existing slot is used. States at MD's 5-plant cap are skipped. |
| Composite Plant (every state, +1 building slot each) | The same for composite plants. |
| Add a research slot | +1 research slot. |
| Add 1,000 army, navy and air experience | +1,000 of each. |

No "technology researched" window appears for granted technologies. About 86 undated
technologies are never granted: they belong to specific countries' focus trees or are hidden
special-project technologies. Each microchip plant uses 3 tungsten and 2 chromium, each composite
plant 1 rubber, 1 chromium and 1 oil, and both draw energy — building dozens at once can put you
into a resource deficit.

### Repair Variables

The four [repair decisions](#repair-decisions), plus *Repair everything* to run all four at once.

## Value Setter panel

HOI4 gives mod panels **no text input** — they can only react to clicks — so this panel, in the
**Millennium Dawn - Economy & Politics** decision tab, lets you build a number with buttons
instead. It is how Millennium Dawn drives its own rate controls.

1. Build a value with the `-10 / -1 / -0.1 / -0.01 / +0.01 / +0.1 / +1 / +10` buttons (0–100).
   The staged value shows live above them; *Reset* returns it to 0. It is remembered while the
   panel is closed.
2. Apply it:

| Button | Uses the staged value as |
|---|---|
| Apply as Inflation Rate | the inflation rate, as a fraction — stage **0.05** for 5% |
| Apply as Corporate Tax % (0-50) | the corporate tax percentage |
| Apply as Central Bank Rate % (0-20) | MD's policy rate; clamped to 20 |
| Apply as Party Popularity % (0-100) | the popularity of the party chosen with *< Previous / Next >* |

The apply buttons use the same effects as the cheat menu, so both routes behave identically.

**Party popularity:** *< Previous / Next >* step through all 24 parties, shown with this country's
own party names and their current popularity. Applying moves the party's whole outlook by the same
amount, so the party lands exactly on your number: other parties in its outlook keep their share,
and the other outlooks shrink or grow in proportion. Set parties one at a time; because each change
reshapes the other outlooks, set the one you care about most last. Setting the ruling party to 0% is
allowed, but MD may change the government at its next political update.

## Off-map buildings panel

The **Millennium Dawn - Off-Map Buildings** decision tab uses the same stepper: set how many
buildings one click adds with `-100 / -10 / -5 / -1 / +1 / +5 / +10 / +100` (up to 1,000), then
click a building type. The building buttons are greyed out while the count is 0.

Off-map buildings belong to your country but to no state, so they need no slots and cannot be
bombed or captured. Because Millennium Dawn counts buildings state by state, only types that still
work without a state are offered:

| Offered | Why it works off-map |
|---|---|
| Civilian factories, military factories, dockyards | the game engine's own production |
| Nuclear reactors, fossil power plants | MD's energy model reads their country-wide bonus |
| Synthetic refineries, agriculture districts, fuel silos | country-wide fuel bonuses |

Left out because they would do nothing: microchip and composite plants and offices (their output
belongs to a state), renewables (MD reads a per-state value), and enrichment facilities (gated on
MD's per-state count). Off-map factories add production but **no GDP or tax income**, and off-map
reactors and power plants burn fuel like any other.

## National idea columns

In the national ideas view, under **MD Cheats - Economy & Politics**. Picking a tier swaps it in;
*Nothing* removes it. All are free to change.

| Column | Tiers | Effect |
|---|---|---|
| **MD Economy Cheats** | Lv1–Lv4, Insane | Productivity growth, workforce, factory and office productivity, tax and seigniorage income, investment returns, international market income; lowers the interest rate and inflation's cost. Lv1 is modest (+10% productivity growth, +10% workforce); Insane is +500% on most of them. |
| **MD Counter-Terror Cheats** | Lv1–Lv4, Insane, Blind | Threat detection and base detection/defence, from +25% / +5 at Lv1 to +1000% / +500 at Insane. *Blind* removes detection entirely, for testing terror events. |
| **MD Energy Cheats** | Lv1–Lv4, Insane (named *Power Grid*) | More energy generation and storage, less consumption. Lv4 adds a flat +500 GW; Insane adds +10,000 GW, cuts consumption and reactor and power-plant fuel use by 95%. |

These are the persistent route for values MD recalculates constantly — see
[things worth knowing](#things-worth-knowing-before-you-use-it).

## Repair decisions

If a value ends up out of range — through a bug, a mid-test edit, or the console — each system has
a decision in the **Millennium Dawn - Economy & Politics** tab that restores **Millennium Dawn's own
bounds**, not bounds invented here, and refreshes the affected panels. No save restart needed.

| Decision | Restores |
|---|---|
| Repair: Economy Variables | debt ≥ 0; corporate and population tax 0–50; central bank rate 0–20; GDP ≥ 0.1; clears queued money-printing inflation; recalculates inflation and the economy |
| Repair: Politics Variables | domestic influence 0–100; all 23 internal faction opinions 0–100, with their effects re-applied; recalculates influence |
| Repair: Counter-Terror Variables | home defence and base detection ≥ 0; recalculates threat detection |
| Repair: Energy Variables | stored energy ≥ 0; recalculates the grid |

Repair does **not** touch a negative treasury: MD allows it, and converts it into debt on its own.

## Things worth knowing before you use it

**Some values cannot be set permanently, and the mod says so rather than pretending.** MD
rebuilds GDP, GDP per capita, interest rate and the whole energy balance from their inputs on
every economy refresh — weekly, and immediately on any focus, decision or event. Writing those
variables directly lasts exactly until the next refresh. Where that applies, the menu offers
both the transient poke (useful for one-tick tests) and a persistent idea column that moves the
inputs instead. Inflation is the exception: it only recalculates quarterly, so a set value holds
for up to three months.

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

**Several options run MD's full economy recalculation** — workforce staffing, every-state
buildings, debt, tax and inflation changes — so a brief pause after clicking is normal.

## Testing

[TESTING.md](TESTING.md) has a per-option checklist: the exact in-game step that confirms each
cheat applied, including the cases where the expected result is that a value *drifts back*.

## Loading without Millennium Dawn

Every decision, idea and menu entry is gated, so nothing can execute. HOI4 will still log
unknown-effect lines to `error.log` at parse time, because the MD effects this mod calls do not
exist. That is expected and harmless; the declared dependencies mean it should not arise in
normal use.

## Development

### Generated technology list

`common/scripted_effects/zz_ebmd_tech_generated.txt` is produced by
`python3 tools/gen_tech_effect.py` from Millennium Dawn's own tech tree — HOI4 script cannot
iterate technologies, so each of the 1,395 dated techs is named explicitly and grouped by
`start_year` behind a date trigger. The same generator writes the microchip and composite option,
selected by MD's `CAT_microchips` / `CAT_composites` categories rather than by date. Every block
carries `popup = no`, so granting hundreds of technologies does not bury the screen in
"technology researched" windows. Regenerate the list after an MD update; `package.sh` refuses to
build a stale one.

### Workshop cover image

`thumbnail.png` (500x500, matching Millennium Dawn's) is drawn by
`python3 tools/gen_thumbnail.py` rather than stored as an opaque binary — the wordmark is the
mod's own name, so a rename is a re-run instead of a hunt for the source file. `descriptor.mod`
and the launcher pointer both carry `picture="thumbnail.png"`, which is what the majority of
installed mods use; Steam needs the file under 1 MB and the generator fails if it isn't.

### Packaging for the Steam Workshop

```bash
./package.sh            # build build/MD-Easybuff-Patch/
./package.sh --zip      # also write build/MD-Easybuff-Patch-<version>.zip
./package.sh -o DIR     # output somewhere else
./package.sh --clean    # delete the output
```

The package contains only what the game reads — `common/`, `events/`, `localisation/`,
`interface/`, `descriptor.mod`, `thumbnail.png`. The README, install and uninstall scripts, `tools/`,
`.claude/` config and `.git/` are left out.

It validates before staging and **refuses to package** on a brace mismatch, a wrong BOM, a
missing localisation key, a call to an MD effect that doesn't exist in 2.0, a stale technology
list, or a panel button with no matching handler. All of these produce no in-game error — the mod
just silently loads nothing, or a button does nothing — so they must not reach a published upload.
It then re-verifies the staged copy rather than trusting `cp`.

**The name loses "Beta" on the way out.** The working copy is named
`+Easybuff - MD Systems Beta`, so the launcher shows which build you have installed locally.
`package.sh` rewrites only the staged `descriptor.mod` to `+Easybuff - MD Systems` — the repo
keeps the Beta name. The strip is word-boundary matched and scoped to the `name=` line, so a
dependency that legitimately contains "Beta" (Millennium Dawn ships *A Beta Test Mod*) is left
alone. Drop "Beta" from `descriptor.mod` when you want the release name locally too.

Point the Paradox launcher at the built folder to publish.
