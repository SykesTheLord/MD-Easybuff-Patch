#!/usr/bin/env python3
"""Regenerate the technology cheat effects from Millennium Dawn's tech tree.

HOI4 script cannot iterate technologies, so "research everything available by now"
has to be written out as explicit set_technology calls. This reads MD's
common/technologies/*.txt, buckets every tech by its start_year, and emits one
date-guarded block per year.

Re-run after an MD update: techs get added, renamed and re-dated, and a stale list
silently grants the wrong set.

    python3 tools/gen_tech_effect.py [--md PATH] [--check]

--check exits 1 if the generated file is out of date, without writing.
"""
import argparse, glob, os, re, sys

OUT = "common/scripted_effects/zz_ebmd_tech_generated.txt"
HEADER = """# +Easybuff - MD Systems
# GENERATED FILE - do not edit by hand.
# Regenerate with: python3 tools/gen_tech_effect.py
#
# HOI4 script cannot loop over technologies, so each one is named explicitly.
# Techs are grouped by MD's start_year and guarded by a vanilla date trigger, so
# "to date" means what the tech tree itself considers available now.
# Source: {n} technologies across {b} start years, from MD's common/technologies/.
# Technologies without a start_year are deliberately excluded: they are unlocked by a
# specific country's focuses, or are hidden special-project techs.
# Every block carries popup = no: without it the engine shows one "technology
# researched" window per tech, which is unusable when granting hundreds at once.

"""


# Resource-chain techs granted by their own option, whatever their date.
RESOURCE_CATS = ("CAT_microchips", "CAT_composites")


def extract(md):
    """(tech name -> start_year, tech name -> categories), walking brace depth inside
    `technologies = { }`. Only techs with a start_year get a date; every tech gets its
    categories, since the resource-chain option selects by category, not by date."""
    techs, cats = {}, {}
    for f in sorted(glob.glob(os.path.join(md, "common/technologies/*.txt"))):
        src = re.sub(r"#[^\n]*", "", open(f, encoding="utf-8-sig", errors="replace").read())
        i = src.find("technologies")
        if i < 0:
            continue
        i = src.index("{", i)
        body = src[i:]
        depth, cur, start = 0, None, 0
        for m in re.finditer(r"([A-Za-z_@][\w.]*)\s*=\s*\{|\{|\}|start_year\s*=\s*(\d+)", body):
            if m.group(2):
                if depth == 2 and cur:
                    techs.setdefault(cur, int(m.group(2)))
            elif m.group(1):
                depth += 1
                if depth == 2:
                    cur, start = m.group(1), m.start()
            elif m.group(0) == "{":
                depth += 1
            else:
                depth -= 1
                if depth < 2:
                    if cur:
                        c = re.search(r"\bcategories\s*=\s*\{([^}]*)\}", body[start:m.end()])
                        cats.setdefault(cur, set(c.group(1).split()) if c else set())
                    cur = None
    return techs, cats


def render(techs, cats):
    buckets = {}
    for name, year in sorted(techs.items()):
        buckets.setdefault(year, []).append(name)

    out = [HEADER.format(n=len(techs), b=len(buckets))]

    def block(names, indent="\t\t"):
        """set_technology takes many at once; wrap so lines stay readable.

        popup = no suppresses the "technology researched" window the engine would
        otherwise throw for every single tech - unusable when granting hundreds at
        once. It is a per-block key, so one line covers every tech in the block.
        """
        lines, row = [], []
        for n in names:
            row.append("%s = 1" % n)
            if len(row) == 4:
                lines.append(indent + "\t" + " ".join(row))
                row = []
        if row:
            lines.append(indent + "\t" + " ".join(row))
        lines.append(indent + "\tpopup = no")
        return indent + "set_technology = {\n" + "\n".join(lines) + "\n" + indent + "}"

    out.append("# Grants every technology whose start_year has already been reached.\n")
    out.append("ebmd_research_techs_to_date = {\n")
    for year in sorted(buckets):
        out.append("\tif = {\n\t\tlimit = { date > %d.12.31 }\n" % (year - 1))
        out.append(block(buckets[year]) + "\n\t}\n")
    out.append("}\n\n")

    out.append("# Grants the entire tree, including technologies dated in the future.\n")
    out.append("ebmd_research_all_techs = {\n")
    for year in sorted(buckets):
        out.append(block(buckets[year], "\t") + "\n")
    out.append("}\n")

    chain = sorted((n for n, c in cats.items() if c.intersection(RESOURCE_CATS)),
                   key=lambda n: (techs.get(n, 0), n))
    if not chain:
        sys.exit("error: no %s technologies found - MD may have renamed the categories"
                 % " / ".join(RESOURCE_CATS))
    out.append("\n# Grants every %s technology, whatever its date (%d techs).\n"
               % (" and ".join(RESOURCE_CATS), len(chain)))
    out.append("# MD's allow blocks require the sp_microchip_production / sp_composite_production\n")
    out.append("# special projects; set_technology ignores allow, so neither project is needed.\n")
    out.append("ebmd_research_microchip_composite_techs = {\n")
    out.append(block(chain, "\t") + "\n")
    out.append("}\n")
    return "".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--md", default=os.path.expanduser("~/Projects/Millennium-Dawn"))
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()

    if not os.path.isdir(os.path.join(a.md, "common/technologies")):
        sys.exit("error: no MD technologies at %s (pass --md PATH)" % a.md)

    techs, cats = extract(a.md)
    if not techs:
        sys.exit("error: parsed 0 technologies - MD's file format may have changed")
    text = render(techs, cats)

    if a.check:
        cur = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if cur != text:
            sys.exit("out of date: re-run python3 tools/gen_tech_effect.py")
        print("up to date (%d technologies)" % len(techs))
        return

    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    print("wrote %s: %d technologies, %d start years" % (OUT, len(techs), len(set(techs.values()))))


if __name__ == "__main__":
    main()
