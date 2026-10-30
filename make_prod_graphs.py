import json
import sys

DUMP = sys.argv[1] if len(sys.argv) > 1 else "data-raw-dump.json"
d = json.load(open(DUMP))

# Recipe filters: these categories are auto-generated reverse/void recipes that would otherwise dominate the graph
EXCLUDED_CATEGORIES = {"recycling", "kr-void-crushing", "kr-fuel-burning", "parameters"}
EXCLUDED_SUBGROUPS = {"fill-barrel", "empty-barrel"}
INCLUDE_HIDDEN = False


"""
"/Users/benjaminlaflen/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio" --dump-data
python3 make_prod_graphs.py '/Users/benjaminlaflen/Library/Application Support/factorio/script-output/data-raw-dump.json'
dot -Tsvg tech_tree.dot -o tech_tree.svg
sfdp -Goverlap=prism -Tsvg production.dot -o production.svg
"""


def q(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def amount(p):
    if "amount" in p:
        a = p["amount"]
    else:
        a = f'{p.get("amount_min", "?")}-{p.get("amount_max", "?")}'
    if p.get("probability", 1) != 1:
        a = f'{a} @{p["probability"]:.0%}'
    return a


unlocked_by = {}
for t in d["technology"].values():
    for e in t.get("effects") or []:
        if e.get("type") == "unlock-recipe":
            unlocked_by.setdefault(e["recipe"], []).append(t["name"])

# Tech tree
out = ["digraph tech {", "rankdir=LR;", "node [shape=box, style=filled, fillcolor=white, fontsize=10];"]
for t in d["technology"].values():
    if "unit" in t:
        u = t["unit"]
        count = u.get("count", u.get("count_formula", "?"))
        cost = f'{count} x ({", ".join(i[0].replace("-science-pack", "") for i in u.get("ingredients", []))}) {u.get("time", "?")}s'
        fill = "white"
    else:
        rt = t.get("research_trigger", {})
        cost = "trigger: " + rt.get("type", "?") + " " + str(rt.get("item") or rt.get("entity") or rt.get("fluid") or "")
        fill = "lightyellow"
    if t.get("max_level"):
        cost += f' (max {t["max_level"]})'
    unlocks = [e.get("recipe") or e.get("space_location") or e["type"] for e in t.get("effects") or []]
    attrs = f'label={q(t["name"] + "\n" + cost)}, tooltip={q("unlocks: " + ", ".join(map(str, unlocks)))}, fillcolor={fill}'
    if t.get("hidden") or t.get("enabled") is False:
        attrs += ", style=\"filled,dashed\""
    out.append(f'{q("tech:" + t["name"])} [{attrs}];')
    for p in t.get("prerequisites") or []:
        out.append(f'{q("tech:" + p)} -> {q("tech:" + t["name"])};')
out.append("}")
open("tech_tree.dot", "w").write("\n".join(out))

# Production chain
out = ["digraph production {", "rankdir=LR;", "node [fontsize=10];"]
materials = set()


def mat(kind, name):
    materials.add((kind, name))
    return q(f"{kind}:{name}")


for r in d["recipe"].values():
    if r.get("category", "crafting") in EXCLUDED_CATEGORIES or r.get("subgroup") in EXCLUDED_SUBGROUPS:
        continue
    if r.get("hidden") and not INCLUDE_HIDDEN:
        continue
    results = r.get("results") or []
    if isinstance(results, dict) or not results:
        continue
    label = f'{r["name"]}\n[{r.get("category", "crafting")}] {r.get("energy_required", 0.5)}s'
    fill = "lightblue"
    if r.get("surface_conditions"):
        label += "\n" + ", ".join(f'{c["property"]}:{c.get("min", "")}..{c.get("max", "")}' for c in r["surface_conditions"])
        fill = "lightsalmon"
    if r.get("enabled", True) is False and r["name"] not in unlocked_by:
        fill = "red"
    tooltip = "unlocked by: " + ", ".join(unlocked_by.get(r["name"], ["(enabled at start)" if r.get("enabled", True) else "NOTHING"]))
    rid = q("recipe:" + r["name"])
    out.append(f'{rid} [shape=box, style=filled, fillcolor={fill}, label={q(label)}, tooltip={q(tooltip)}];')
    for i in r.get("ingredients") or []:
        out.append(f'{mat(i["type"], i["name"])} -> {rid} [label={q(amount(i))}];')
    for p in results:
        out.append(f'{rid} -> {mat(p["type"], p["name"])} [label={q(amount(p))}];')

sources = []
for kind in ("resource", "plant", "asteroid-chunk", "fish"):
    for e in d.get(kind, {}).values():
        m = e.get("minable")
        if not m:
            continue
        prods = m.get("results") or ([{"type": "item", "name": m["result"], "amount": m.get("count", 1)}] if m.get("result") else [])
        sources.append((f"{kind}:{e['name']}", prods, [{"type": "fluid", "name": m["required_fluid"], "amount": m.get("fluid_amount", "?")}] if m.get("required_fluid") else []))
for kind in ("tree", "simple-entity"):
    prods = {}
    for e in d.get(kind, {}).values():
        m = e.get("minable") or {}
        for p in m.get("results") or ([{"type": "item", "name": m["result"], "amount": m.get("count", 1)}] if m.get("result") else []):
            prods[(p.get("type", "item"), p["name"])] = p
    sources.append((f"{kind}:(all)", list(prods.values()), []))
for f in sorted({t["fluid"] for t in d["tile"].values() if t.get("fluid")}):
    sources.append((f"offshore:{f}", [{"type": "fluid", "name": f, "amount": "pump"}], []))
for b in d.get("boiler", {}).values():
    i, o = b.get("fluid_box", {}).get("filter"), b.get("output_fluid_box", {}).get("filter")
    if i and o:
        sources.append((f"boiler:{b['name']}", [{"type": "fluid", "name": o, "amount": "heat"}], [{"type": "fluid", "name": i, "amount": "heat"}]))

for name, prods, inputs in sources:
    if not prods:
        continue
    out.append(f'{q("source:" + name)} [shape=house, style=filled, fillcolor=palegreen, label={q(name)}];')
    for i in inputs:
        out.append(f'{mat(i["type"], i["name"])} -> {q("source:" + name)} [label={q(amount(i))}];')
    for p in prods:
        out.append(f'{q("source:" + name)} -> {mat(p.get("type", "item"), p["name"])} [label={q(amount(p))}];')

item_types = [k for k, v in d.items() if isinstance(v, dict) and any(isinstance(x, dict) and "stack_size" in x for x in v.values())]
for kind, name in list(materials):
    if kind != "item":
        continue
    proto = next((d[t][name] for t in item_types if name in d[t]), {})
    if proto.get("spoil_result"):
        out.append(f'{mat("item", name)} -> {mat("item", proto["spoil_result"])} [style=dashed, label="spoils"];')
    if proto.get("burnt_result"):
        out.append(f'{mat("item", name)} -> {mat("item", proto["burnt_result"])} [style=dashed, label="burnt"];')
    for p in proto.get("rocket_launch_products") or []:
        out.append(f'{mat("item", name)} -> {mat(p.get("type", "item"), p["name"])} [style=dashed, label={q("launch " + str(amount(p)))}];')

for kind, name in sorted(materials):
    shape = "ellipse" if kind == "item" else "diamond"
    color = "white" if kind == "item" else "lightcyan"
    out.append(f'{q(kind + ":" + name)} [shape={shape}, style=filled, fillcolor={color}, label={q(name)}];')
out.append("}")
open("production.dot", "w").write("\n".join(out))