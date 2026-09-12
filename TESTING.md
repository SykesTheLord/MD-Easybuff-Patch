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

## Per-option checks

The menu nests: the hub lists categories, and the larger categories open a sub-page
(Economy -> Debt & Interest / Treasury & Costs / Tax & Corruption / GDP; Money & Inflation ->
Monetary Expansion / Inflation & Central Bank; Internal Factions -> Individual Factions).
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
| Recalculate the grid | panel figures refresh without waiting for the daily tick |

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
