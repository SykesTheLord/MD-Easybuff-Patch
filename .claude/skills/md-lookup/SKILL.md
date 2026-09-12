---
name: md-lookup
description: Find the real Millennium Dawn 2.0 name, signature and input variables for an effect, variable, modifier or event, and report when MD's published documentation disagrees with the source. Use before calling any MD identifier from this patch.
---

Look up `$ARGUMENTS` in the MD 2.0 source. **The source is the authority** — MD's published
scripted-effects reference documents the released 1.12.x mod, not the 2.0 branch this patch
targets, and is wrong in several places.

```bash
MD=~/Projects/Millennium-Dawn
```

## Resolve it

Try each until one hits:

```bash
# scripted effect or trigger (gives the definition line)
grep -rnE "^$NAME = \{" $MD/common/scripted_effects/ $MD/common/scripted_triggers/

# modifier
grep -rnE "^\s*$NAME = \{" $MD/common/modifier_definitions/

# country/state variable - find where it is set, to learn its scale and owner
grep -rn "set_variable = { $NAME\|set_variable = { var = $NAME" $MD/common/

# event id
grep -rnE "id = $NAME\s*$" $MD/events/

# fuzzy, when the exact name is unknown
grep -rhoE "^[a-z_]*${NAME}[a-z_]* = \{" $MD/common/scripted_effects/ | sort -u
```

## Read the definition before using it

Print the body and report:

1. **Required inputs.** MD effects take `set_temp_variable` arguments, not parameters. The
   defining file usually documents them in a `# Required Input:` comment above. Distinguish
   required from optional — and note any the effect *branches* on, since leaving one unset makes
   behaviour depend on whatever ran earlier in the same execution.
2. **Scope.** Country or state? Check whether the body uses `every_controlled_state` /
   `random_owned_controlled_state` internally (so it is country-scoped) or expects to already be
   in a state.
3. **Clamps and guards.** Note `clamp_variable` bounds and any `if = { limit = { has_idea = ... } }`
   wrapper that makes the effect a silent no-op.
4. **Free/skip inputs.** Several MD effects honour `skip_payment = 1` or a country flag like
   `MD_skip_treasury_cost` to bypass their cost. Always check — it is usually what a cheat wants.
5. **Refresh hooks.** Does it already call `ingame_update_setup` / `update_money_dirty_variable`
   / `calculate_energy_use`? If not, the caller must.
6. **Whether it is recalculated.** If the value is rebuilt by a pulse effect, say so — a direct
   set will not hold, and the cheat belongs in an idea column instead.

## Check the docs for drift

```bash
grep -n "$NAME" $MD/docs/src/content/resources/scripted-effects-reference.md
```

If the doc shows a different name or different inputs than the source, **report the divergence
explicitly** and use the source. Known drift already found: the five `modify_*_spending` budget
effects do not exist; `add_relative_party_popularity` is `change_relative_party_popularity`; the
faction opinion input is `temp_opinion`; `build_battery_parks` is `build_battery_park_effect`.

## Confirm it is not 1.12.x-only

If the identifier is being added to this patch, sanity-check that it exists in 2.0 specifically —
never verify against the installed Workshop copy, which is 1.12.3b and a different codebase.

## Report

Give the `path:line`, the exact call syntax to use (temp variables then the `= yes` call), the
scope it must be called in, and any caveat from the checks above.
