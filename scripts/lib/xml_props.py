#!/usr/bin/env python3
"""Set <property><name>/<value> pairs in a Hadoop-style XML configuration file.

Used for ranger-admin-site.xml and zeppelin-site.xml. The edit is deliberately dumb and safe:
  * the file is changed in place with a regular expression, so comments and layout survive;
  * every property must match exactly once (0 matches: it is added, >1: the run aborts);
  * the result is parsed as XML before anything is written;
  * nothing is written when nothing changed, so the script is idempotent.

usage: xml_props.py FILE PROPS [--check]
  PROPS  lines of name=value ('#' comments and blank lines ignored; the first '=' splits)
  --check  report what would change and exit 1 if anything would, writing nothing
"""
import re
import sys
import xml.dom.minidom
from xml.sax.saxutils import escape


def read_props(path):
    props = []
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                sys.exit(f"bad line in {path}: {line!r}")
            name, value = line.split("=", 1)
            props.append((name.strip(), value.strip()))
    return props


def apply(text, props):
    report = []
    for name, value in props:
        esc = escape(value)
        pair = re.compile(r"(<name>\s*" + re.escape(name) + r"\s*</name>\s*<value>)(.*?)(</value>)", re.S)
        empty = re.compile(r"(<name>\s*" + re.escape(name) + r"\s*</name>\s*)<value\s*/>")
        n_pair, n_empty = len(pair.findall(text)), len(empty.findall(text))
        if n_pair + n_empty > 1:
            sys.exit(f"{name}: found {n_pair + n_empty} times, refusing to guess")
        if n_pair == 1:
            old = pair.search(text).group(2)
            if old == esc:
                report.append((name, "unchanged"))
            else:
                text = pair.sub(lambda m: m.group(1) + esc + m.group(3), text, count=1)
                report.append((name, "replaced"))
        elif n_empty == 1:
            text = empty.sub(lambda m: m.group(1) + "<value>" + esc + "</value>", text, count=1)
            report.append((name, "replaced"))
        else:
            block = f"  <property>\n    <name>{name}</name>\n    <value>{esc}</value>\n  </property>\n"
            if "</configuration>" not in text:
                sys.exit("no </configuration> element to add the property to")
            text = text.replace("</configuration>", block + "</configuration>", 1)
            report.append((name, "added"))
    return text, report


def main():
    args = [a for a in sys.argv[1:] if a != "--check"]
    check = "--check" in sys.argv[1:]
    if len(args) != 2:
        sys.exit(__doc__)
    path, props_path = args
    with open(path, encoding="utf-8") as fh:
        original = fh.read()
    text, report = apply(original, read_props(props_path))
    xml.dom.minidom.parseString(text.encode("utf-8"))   # must still be well-formed XML
    for name, state in report:
        print(f"  {name}: {state}")
    changed = text != original
    if check:
        sys.exit(1 if changed else 0)
    if changed:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)


if __name__ == "__main__":
    main()
