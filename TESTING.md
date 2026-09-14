# Test checklist

No automated harness exists for HOI4 script; everything below is an in-game check.

## Load-time

1. Enable **Millennium Dawn → +Easybuff → +Easybuff — MD Systems**, in that order, and start
   any 2000 scenario.
2. Check `~/.local/share/Paradox Interactive/Hearts of Iron IV/logs/error.log` for new lines
   mentioning `ebmd` — unknown effect, unknown trigger, or duplicate key. There should be none.
3. Confirm the **Millennium Dawn — Economy & Politics** decision tab exists and the **MD Cheats**
   idea column appears in the national ideas view.
4. Disable Millennium Dawn and reload: the decision tab and the menu idea must be hidden.
   Unknown-effect lines in `error.log` are expected here; a crash is not.

## Uninstall

Run against the local install, after quitting the game and launcher.

| Step | Confirm |
|---|---|
| `./uninstall.sh --dry-run` (or `-DryRun`) | lists the link or folder, the `.mod` pointer and the `dlc_load.json` entry; nothing changes on disk |
| `./uninstall.sh` (or `.\uninstall.ps1`) | `mod/MD-Easybuff-Patch` and `mod/+Easybuff-MD-Systems.mod` are gone; **the repo is intact**; `dlc_load.json` no longer lists the mod but still lists your other enabled mods; `dlc_load.json.bak` exists |
| Launch the launcher | the mod is no longer listed (restart it once if it is); the game starts without complaining about a missing mod |
| Run it again | reports nothing installed |

## Per-option checks

The menu nests. The hub lists Economy, Politics, Counter-Terrorism, Power Grid, Technology and
Repair, and the larger categories open sub-pages:
- Economy -> Debt & Interest / Treasury & Costs / Tax & Corruption / GDP / Workforce /
  Monetary Expansion / Inflation & Central Bank
- Politics -> Internal Factions & Parties (-> Individual Factions) / Foreign Influence /
  Fire / Suppress Events / Ruling Party (-> five outlook pages)
- Power Grid -> Power Construction
Applying an option returns you to the page you were on, so several can be chained; Back steps
up one level.

**Check no page is cut off:** every page must show its Back row. If the bottom option is
missing, that page is over the 11-option limit.

Each economy row: open the decision → *Open MD Systems Cheat Menu* → the listed category.
Use `tdebug` to read variables on hover, or
`effect log = "debt=[?THIS.debt] ir=[?THIS.interest_rate]"` and read `logs/game.log`.

### Economy

| Option | Confirm |
|---|---|
| Wipe debt | debt widget reads 0; on the next weekly tick interest rate falls to 0 (MD's zero-debt branch) |
| Set debt to 100 | widget reads 100; debt ratio updates the same tick |
| Force interest above 15% | after one weekly tick the `very_high_interest_country_modifiers` entry appears in the modifier tooltip and construction speed drops |
| Force interest above 25% | `tag` to an AI in the same position and confirm `bankruptcy_default_on_debts` is now something the AI will take |
| Set treasury | treasury widget matches immediately; try it with the economy panel open to confirm the refresh |
| Toggle free MD costs | take any MD decision with a treasury cost — treasury must not drop. Toggle again and confirm it does |
| Corporate tax 0% / 50% | budget tab shows the new rate and tax income recalculates in the same tick |
| Corruption to minimum | national ideas show `corruption_level_01`; the previous tier is gone |
| Corruption to maximum | national ideas show `corruption_level_10` |

### GDP

| Option | Confirm |
|---|---|
| Warning screen | opening *GDP...* shows the desync explanation before any value changes |
| Double GDP | GDP widget doubles immediately; **after one weekly tick it has drifted back** — documented behaviour, not a bug |
| Lv4 economy idea | GDP trends upward over several months instead of snapping back |
| Double productivity | state productivity roughly doubles in the state view; GDP follows over following weeks |

### Workforce

Use a factory-heavy country with a labour shortage (unemployment at or near 0% in the economy view).

| Option | Confirm |
|---|---|
| Staff every factory | population rises, mostly in the states with the most factories; unemployment settles between 2% and 5%; civilian and military factory fulfillment read 100% |
| Run it again straight away | nothing changes - unemployment is already 2% or more, so no sector is short |
| Country already above 2% unemployment | nothing is added |

**Load-bearing:** if population does not rise at all, state `add_manpower` is not reflected
until the next tick. The effect detects that and stops after one step by design, so it cannot
loop - but the option would then need to spread its steps across days instead. Report it.

It re-runs MD's economy calculation up to about 27 times in one click; a brief hitch on large
countries is expected.

### Money and inflation

| Option | Confirm |
|---|---|
| Grant monetary expansion | `monetary_expand_active_idea` appears in national ideas; seigniorage income rises in the budget breakdown; **`currency_strength` is unchanged** and no `monetary_expand_cooldown` flag is set |
| Permanent variant | same, with no expiry timer on the idea |
| Print 500 / 5,000 free | treasury rises; political power does **not** drop; `print_money_base_add` stays 0 and no `printed_money_recently` flag appears |
| Set inflation to 0% | inflation readout drops immediately **and** the derived penalties (construction speed, goods cost) ease in the same tick — this confirms the derived-variable refresh ran |
| Inflation persistence | advance past the next quarter boundary (month 3, 6, 9 or 12) and confirm inflation recomputes from MD's model rather than staying pinned |
| CB rate to 15% | inflation falls over the following quarter **and** interest rate rises by roughly half the policy rate on the next weekly tick — the documented trade-off |
| CB rate to 0% | reverses the above |

### Politics

| Option | Confirm |
|---|---|
| Set every faction to 100 | every faction your country actually has reads 100 in the politics view |
| All factions ±25 | each present faction moves by 25, clamped at 0 and 100 |
| Oligarchs / Military ±50 | that faction's bar moves; play a country **without** that faction and confirm the option is silently ignored rather than erroring |
| Ruling party +50% | the ruling party's popularity rises in the politics view |

### Ruling party

Politics -> Ruling Party.

| Option | Confirm |
|---|---|
| Open any outlook page | each option shows this country's own party name followed by MD's generic name, e.g. "Republican Party (Conservatism)"; a country with no named party still shows the generic name |
| Pick a party | the politics view shows it ruling; its popularity rose; the page's "Currently in power" line updates when it reopens |
| Pick a party in a country without elections | elections are **still disabled** afterwards (MD's own cheat would have re-enabled them) |
| Put the largest party in power | the most popular party in the politics view takes over, with popularity unchanged; if it already rules, nothing visible changes |

### Influence

| Option | Confirm |
|---|---|
| Max influence over neighbours | open a neighbour's influence view — your share is at the cap and the other influencers have been renormalised so the total is still 100% |
| +25% over majors | each major shows your share up by 25 points, capped at the remaining headroom |
| Reset domestic influence | your own domestic influence reads 100 |

### Events

| Option | Confirm |
|---|---|
| Each *Fire:* option | the named MD event window appears, and the cheat menu reopens behind it so you can fire another |
| Suppress corruption | fire the corruption roll again — it declines automatically |
| Allow corruption again | the roll behaves normally |

### Counter-terrorism

| Option | Confirm |
|---|---|
| Max capability | counter-terror defence total rises in the CT panel after the next weekly CT bucket |
| Zero capability | the same value drops to the modifier-only baseline |
| Insane / Blind idea | persists across weekly ticks, unlike the raw setters |
| Spawn one organisation | the CT view lists one more organisation; its HQ state shows the `is_regional_terror_base` flag under `tdebug`. If MD's inactive pool is empty nothing happens — expected |
| Remove every organisation | the list empties, no console errors, and each country's intel arrays shrink in step |

### Energy

| Option | Confirm |
|---|---|
| Lv3 / Insane grid idea | energy panel generation rises and consumption falls immediately |
| Build battery parks | storage capacity rises by the expected amount and **treasury does not drop** (free build path) |
| Hydroelectric | the chosen state gains hydroelectric generation and storage |
| 3 nuclear reactors | reactors appear and generation rises after the recalculation |
| Renewable Energy Infrastructure (every state) | every owned state gains one level; states already at 20 are unchanged; renewable generation rises after the recalculation |
| Any every-state build option (renewables, enrichment, microchip or composite plants) | the page **reopens** after the click. If it closes instead, copy the last lines of `error.log` from that moment - the reopen is queued before the build, so a close means the option itself failed to load |
| Nuclear Enrichment Facility (every state) | every owned state without one gains a facility; Nuclear Technology is researched; the energy view shows reactor fuel production switched on and net nuclear fuel rising |

The battery park, hydroelectric, reactor and every-state options live on the **Power Construction**
sub-page, opened from Power Grid.

Run *Nuclear Enrichment Facility* a second time: no state gains another (cap of 1), and the fuel
stockpile is **not** reset to 300.
| Recalculate the grid | panel figures refresh without waiting for the daily tick |

### Value Setter (scripted GUI)

Open the **Millennium Dawn — Economy & Politics** decision tab; the panel sits above the
decisions.

| Step | Confirm |
|---|---|
| Click `+1` | the readout changes to 1.00 **immediately** — if it only updates after reopening the tab, the `dirty` variable is not wired |
| Click `-0.01` four times | readout reads 0.96, proving fractional steps accumulate |
| Click `-10` repeatedly | readout stops at 0.00, never negative |
| Stage 0.05 → *Apply as Inflation Rate* | inflation reads 5% and the derived penalties move |
| Stage 35 → *Apply as Corporate Tax* | budget tab shows 35% |
| Stage 90 → *Apply as Central Bank Rate* | clamps to 20, MD's own maximum |
| Reset | readout returns to 0.00 |
| *Next >* / *< Previous* | the party line shows this country's own party name and its current popularity; *< Previous* from the first party wraps to the last |
| Stage 40 → *Apply as Party Popularity %* | the politics view shows that party at 40%; other parties in its outlook keep their share; the other outlooks shrink in proportion; the party line updates immediately |
| Stage 0 → *Apply as Party Popularity %* on the ruling party | it drops to 0% - MD may then change the government at its next political update |

The staged value persists while the panel is closed — it is a country variable, not scratch state.

### Off-map buildings (scripted GUI)

Open the **Millennium Dawn - Off-Map Buildings** decision tab.

| Step | Confirm |
|---|---|
| Open the tab | the category shows even though it has no decisions - if it is missing, `visible_when_empty` is not taking effect |
| Count at 0 | all eight building buttons are greyed out |
| Click `+10`, then `-1` | readout reads 9, a whole number |
| Click `-100` | readout stops at 0 |
| Stage 5 → *Civilian Factories* | production screen shows 5 more civilian factories; no state gains one |
| Stage 2 → *Nuclear Reactors* | energy panel generation rises straight away; nuclear fuel consumption rises too |
| Stage 3 → *Military Factories* | 3 more military factories, and GDP does **not** move on the next weekly tick - expected, MD counts factories per state |

### Technology

| Option | Confirm |
|---|---|
| Research everything available by date | research screen fills in up to the current era; technologies dated in the future are **still unresearched** |
| Research every dated technology | the whole dated tree completes, future tiers included |
| Research all microchip and composite technologies | in a 2000 start, all 38 unlock - including 2075 tiers - with neither special project completed; microchip and composite plants become buildable |
| Microchip Plant (every state) | every owned state gains one microchip plant **and** one extra shared building slot, so its free slot count is unchanged; microchip output and tungsten/chromium use rise straight away |
| Composite Plant (every state) | the same with composite plants; composite output and rubber/chromium/oil use rise straight away |

Run *Microchip Plant* and *Composite Plant* once each **before** researching the matching tech:
if no plants appear, the engine requires the tech for `instant_build` and the option needs to grant
`microchip_production_1` / `composite_production_1` first. Then click it five more times on one state: the sixth click adds neither a plant nor a slot
there (MD's cap is 5 per state).
| Add a research slot | slot count rises by one |
| Add 1,000 XP | army, navy and air XP each rise by 1,000 |

Neither research option may show a "technology researched" window. Every `set_technology` block
carries `popup = no`; if even one popup appears, a block lost the line — regenerate the list.

Run the date-limited option in a 2000 start: anything with a `start_year` above 2000 must stay
locked. If future tech appears, the date guard is wrong.

### Repair

For each of the four repair decisions, break the value first, then repair:

```
effect set_variable = { debt = -500 }
effect set_variable = { corporate_tax_rate = 900 }
effect set_variable = { oligarchs_opinion = -40 }
effect set_variable = { ct_home_defense_var = -10 }
effect set_variable = { stored_energy = -100 }
```

Click the matching repair decision and confirm each value returns to MD's own bound
(debt ≥ 0, tax 0–50, opinion 0–100, CT ≥ 0, stored energy ≥ 0; treasury is intentionally left alone) and the affected panel
refreshes. *Repair everything* should fix all of them in one click.
