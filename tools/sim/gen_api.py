"""Turn Roblox's Full-API-Dump.json into tools/sim/api_data.luau for the headless simulator.

Usage: python3 tools/sim/gen_api.py <Full-API-Dump.json>
Keeps, per class: superclass, properties (value type, default, read-only), methods, events, callbacks.
"""
import json
import pathlib
import sys

OUT = pathlib.Path(__file__).resolve().parent / "api_data.luau"
SKIP_DEFAULTS = ("__api_dump", )


def lua_str(s):
    out = ['"']
    for ch in s:
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif 32 <= ord(ch) < 127:
            out.append(ch)
        else:
            out.extend("\\%03d" % b for b in ch.encode("utf-8"))
    out.append('"')
    return "".join(out)


def main(path):
    d = json.load(open(path, encoding="utf-8"))
    out = ["return {", "classes = {"]
    for c in d["Classes"]:
        tags = c.get("Tags") or []
        props, funcs, events, callbacks = [], [], [], []
        for m in c["Members"]:
            mt = m["MemberType"]
            mtags = m.get("Tags") or []
            if mt == "Property":
                vt = m["ValueType"]
                cat = {"Primitive": "P", "DataType": "D", "Enum": "E", "Class": "C"}.get(vt["Category"], "D")
                default = m.get("Default")
                if default is not None and (default.startswith(SKIP_DEFAULTS) or vt["Category"] == "Class"):
                    default = None
                ro = "ReadOnly" in mtags or (m.get("Security", {}).get("Write") not in (None, "None"))
                entry = f'{lua_str(cat)},{lua_str(vt["Name"])},{lua_str(default) if default is not None else "nil"},{"true" if ro else "false"}'
                props.append(f'[{lua_str(m["Name"])}]={{{entry}}}')
            elif mt == "Function":
                funcs.append(f'[{lua_str(m["Name"])}]=true')
            elif mt == "Event":
                events.append(f'[{lua_str(m["Name"])}]=true')
            elif mt == "Callback":
                callbacks.append(f'[{lua_str(m["Name"])}]=true')
        out.append(
            f'[{lua_str(c["Name"])}]={{s={lua_str(c["Superclass"])},nc={"true" if "NotCreatable" in tags else "false"},'
            f'svc={"true" if "Service" in tags else "false"},'
            f'p={{{",".join(props)}}},f={{{",".join(funcs)}}},e={{{",".join(events)}}},cb={{{",".join(callbacks)}}}}},')
    out.append("},")
    out.append("enums = {")
    for e in d["Enums"]:
        items = ",".join(f'{{{lua_str(i["Name"])},{i["Value"]}}}' for i in e["Items"])
        out.append(f'[{lua_str(e["Name"])}]={{{items}}},')
    out.append("},")
    out.append("}")
    OUT.write_text("\n".join(out), encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes, {len(d['Classes'])} classes, {len(d['Enums'])} enums)")


if __name__ == "__main__":
    main(sys.argv[1])
