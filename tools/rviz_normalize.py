#!/usr/bin/env python3
"""Keep volatile / runtime UI-state out of rviz config commits.

rviz rewrites throw-away state on every save: volatile *values* (window geometry,
the base64 ``QMainWindow State`` blob, camera pose, panel tree heights, expanded
nodes, auto-computed bounds) and whole *dynamic subtrees* (e.g. a MultiRobotModel
display gains a child per connected robot, keyed by its ROS namespace ``/athena``).
Committing either produces noisy diffs and merge conflicts.

A maintainable blacklist (``rviz_blacklist.txt`` next to this script) drives two
modes, each used by ``tools/clean_rviz_configs.sh`` (``--write``) and the ``rviz-no-volatile``
pre-commit hook (``--check``):

* ``--check FILE...``  report anything the blacklist flags and exit non-zero. The
  pre-commit framework stashes unstaged changes first, so the file on disk reflects
  the *staged* content being committed.
* ``--write FILE...``  fix the file in place (the clean script). Other edits are
  left untouched.

Blacklist grammar — one rule per non-blank, non-``#`` line:

    [strip ]<selector>/<selector>/...

* Optional ``strip`` prefix → delete matched nodes. Absent ⇒ ``reset`` the matched
  node's subtree to the committed (``HEAD``) value. Reset keeps the key present with
  a stable value; strip removes dynamic content that should not exist at all.
* Path is split on ``/`` that is **not inside ``[...]``** and **not escaped ``\\/``**
  (so regexes/values may contain slashes). Each selector matches children at a level:
  - ``Foo``           literal: a mapping key ``Foo`` or a sequence item named ``Foo``.
  - ``*``             any child.
  - ``**``            recursive descent: zero or more levels (so a rule matches its
                      target at any nesting depth, e.g. displays inside a
                      ``rviz_common/Group``). Terminal ``**`` (e.g. a strip rule's
                      ``.../**/<key>``) matches the current nodes and every descendant.
  - ``~REGEX``        a mapping key / item ``Name`` matching REGEX (``re.search``).
  - ``[Field~REGEX]`` base filter: an item/mapping whose child ``Field`` value matches
                      REGEX; selects the container, the path then descends into it.

For ``strip`` rules the last selector picks which children of the selected container
to delete (e.g. ``[Class~MultiRobotModel]/~^\\/`` → robot-namespace children).

Implementation is **line-wise**, never via a YAML library (a load/dump reorders keys
and reflows scalars, including the base64 line, causing huge churn). Reset splices the
exact ``HEAD`` lines over the working ones; strip rebuilds the affected container,
relocating the YAML list dash when the deleted child sat inline on it. Sequence items
are paired with the baseline by their ``Name`` field, so reordering or inserting a
uniquely-named display does not mis-pair a reset value; same-named (or unnamed)
siblings fall back to positional order. Stripping is baseline-free; a key present
locally but absent from the baseline is left as-is by reset (nothing to reset to).
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

BLACKLIST_PATH = Path(__file__).with_name("rviz_blacklist.txt")


class Node:
    """A YAML mapping entry (``key:``) or sequence item (``- ...``).

    ``start``/``end`` are line indices (``end`` exclusive) spanning the entry and its
    whole indented block. ``children`` are the immediate nested entries. ``value`` is
    the inline scalar after ``key:`` (or None). ``name`` is the ``Name`` child's value,
    used to pair sequence items with the baseline by identity; same-named siblings then
    pair by position.
    """

    __slots__ = ("kind", "key", "value", "indent", "start", "end", "children", "name")

    def __init__(self, kind, key, indent, start, end):
        self.kind = kind  # 'map' or 'item'
        self.key = key  # mapping key, or None for an item
        self.value = None
        self.indent = indent
        self.start = start
        self.end = end
        self.children = []
        self.name = None


class _Root:
    """Synthetic container whose children are the top-level nodes (for strip rules)."""

    __slots__ = ("children",)

    def __init__(self, children):
        self.children = children


def _indent_of(line):
    return len(line) - len(line.lstrip(" "))


def _line_value(line):
    """Scalar value of a ``key: value`` (or sequence-item) line, or None."""
    s = line.lstrip(" ")
    if s.startswith("- "):
        s = s[2:].lstrip(" ")
    elif s == "-":
        return None
    _key, sep, val = s.partition(":")
    return val.strip() if sep else None


def parse_block(lines, start, end, indent):
    """Parse sibling nodes within ``lines[start:end]`` at column ``indent``."""
    nodes = []
    i = start
    while i < end:
        line = lines[i]
        if line.strip() == "":
            i += 1
            continue
        col = _indent_of(line)
        if col < indent:
            break  # dedent ends this block
        if col > indent:
            i += 1  # defensive; should not happen for a well-formed block
            continue
        # A sibling node begins here; its block runs until the next non-blank line at
        # this indent or shallower.
        node_start = i
        j = i + 1
        while j < end:
            nxt = lines[j]
            if nxt.strip() == "" or _indent_of(nxt) > col:
                j += 1
                continue
            break
        node_end = j
        content = line[col:]
        if content.startswith("-"):
            node = Node("item", None, col, node_start, node_end)
            node.children = _parse_item_children(lines, node_start, node_end, col)
        else:
            node = Node("map", content.split(":", 1)[0].rstrip(), col, node_start, node_end)
            node.value = _line_value(line)
            node.children = _parse_children(lines, node_start + 1, node_end, col)
        for child in node.children:
            if child.kind == "map" and child.key == "Name":
                node.name = child.value
                break
        nodes.append(node)
        i = node_end
    return nodes


def _parse_children(lines, start, end, parent_indent):
    """Parse the immediate children (first deeper indent level) of a mapping node."""
    child_indent = None
    for k in range(start, end):
        if lines[k].strip() != "":
            col = _indent_of(lines[k])
            if col > parent_indent:
                child_indent = col
            break
    if child_indent is None:
        return []
    return parse_block(lines, start, end, child_indent)


def _parse_item_children(lines, dash_idx, end, dash_indent):
    """Parse a sequence item's children at ``dash_indent + 2``.

    The item's first key sits inline on the dash line (``- key: ...``) and may carry a
    nested value indented deeper than its siblings, so the child level is fixed at
    ``dash_indent + 2`` rather than the first deeper indent. The dash line is normalized
    (``- `` → spaces) so the inline key aligns with its siblings; child indices are then
    mapped back to the original lines.
    """
    child_indent = dash_indent + 2
    stripped = lines[dash_idx].lstrip(" ")
    after = stripped[1:].lstrip(" ") if stripped.startswith("-") else stripped
    if after == "":
        return _parse_children(lines, dash_idx + 1, end, dash_indent)
    view = [" " * child_indent + after] + lines[dash_idx + 1:end]
    children = parse_block(view, 0, len(view), child_indent)
    _shift(children, dash_idx)
    return children


def _shift(nodes, delta):
    for n in nodes:
        n.start += delta
        n.end += delta
        _shift(n.children, delta)


# --- selectors -------------------------------------------------------------------

def _parse_selector(token):
    token = token.strip()
    if token == "**":
        return ("descend",)
    if token == "*":
        return ("any",)
    if token.startswith("[") and token.endswith("]"):
        field, _sep, regex = token[1:-1].partition("~")
        return ("pred", field.strip(), re.compile(regex))
    if token.startswith("~"):
        return ("rx", re.compile(token[1:]))
    return ("lit", token)


def _split_path(text):
    """Split on ``/`` outside ``[...]`` and not escaped ``\\/``; unescape ``\\/``."""
    tokens, buf, depth, i = [], [], 0, 0
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text) and text[i + 1] == "/":
            buf.append("/")
            i += 2
            continue
        if c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
        if c == "/" and depth == 0:
            tokens.append("".join(buf))
            buf = []
        else:
            buf.append(c)
        i += 1
    tokens.append("".join(buf))
    return [t for t in tokens if t != ""]  # ignore empty segments (leading/trailing/double '/')


def load_blacklist(path=BLACKLIST_PATH):
    """Return a list of (action, selectors) rules."""
    rules = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        action = "reset"
        if line.startswith("strip "):
            action, line = "strip", line[len("strip "):].strip()
        elif line.startswith("reset "):
            line = line[len("reset "):].strip()
        rules.append((action, [_parse_selector(tok) for tok in _split_path(line)]))
    return rules


def _child_value(node, field):
    for c in node.children:
        if c.kind == "map" and c.key == field:
            return c.value
    return None


def sel_match(node, sel):
    """Identity of ``node`` for selector ``sel``, or None if it does not match."""
    kind = sel[0]
    if kind == "any":
        return ("item", node.name) if node.kind == "item" else ("key", node.key)
    if kind == "lit":
        if node.kind == "map" and node.key == sel[1]:
            return ("key", node.key)
        if node.kind == "item" and node.name == sel[1]:
            return ("item", node.name)
        return None
    if kind == "rx":
        if node.kind == "map" and node.key is not None and sel[1].search(node.key):
            return ("key", node.key)
        if node.kind == "item" and node.name is not None and sel[1].search(node.name):
            return ("item", node.name)
        return None
    if kind == "pred":
        val = _child_value(node, sel[1])
        if val is not None and sel[2].search(val):
            return ("item", node.name) if node.kind == "item" else ("key", node.key)
        return None
    return None


def collect(nodes, selectors, prefix=()):
    """Walk ``selectors`` through the tree, returning (identity, node) per match.

    ``identity`` is a tuple of per-level ``(component, ordinal)`` pairs; the ordinal
    disambiguates same-identity siblings by order so identities pair across the working
    and baseline trees.
    """
    head, rest = selectors[0], selectors[1:]
    if head == ("descend",):
        # '**' matches zero or more levels. Zero levels: apply the remaining
        # selectors at this level; when '**' is terminal (a strip rule's container
        # path ending in '**', e.g. '.../**/Namespaces'), the nodes themselves are
        # the matches. One-or-more levels: descend through every child keeping '**'
        # in play. The finite tree terminates the recursion and reaches each match on
        # exactly one path, so there are no duplicates.
        out = list(collect(nodes, rest, prefix)) if rest else []
        counts = {}
        for node in nodes:
            comp = ("item", node.name) if node.kind == "item" else ("key", node.key)
            ordinal = counts.get(comp, 0)
            counts[comp] = ordinal + 1
            ident = prefix + ((comp, ordinal),)
            if not rest:
                out.append((ident, node))
            out.extend(collect(node.children, selectors, ident))
        return out
    out = []
    counts = {}
    for node in nodes:
        comp = sel_match(node, head)
        if comp is None:
            continue
        ordinal = counts.get(comp, 0)
        counts[comp] = ordinal + 1
        ident = prefix + ((comp, ordinal),)
        if rest:
            out.extend(collect(node.children, rest, ident))
        else:
            out.append((ident, node))
    return out


def render_path(ident):
    """Human-readable concrete path from a match identity."""
    return "/".join(value if value is not None else "*" for (_kind, value), _ord in ident)


def _split_lines(text):
    """Split into lines, returning (lines, had_trailing_newline)."""
    had_nl = text.endswith("\n")
    lines = text.split("\n")
    if had_nl:
        lines.pop()  # drop the empty element after the final newline
    return lines, had_nl


def _apply_ops(lines, ops, had_nl):
    """Apply (start, end, replacement) splices; later overlaps are dropped."""
    ops.sort(key=lambda op: (op[0], -op[1]))
    result, cursor = [], 0
    for start, end, replacement in ops:
        if start < cursor:
            continue
        result.extend(lines[cursor:start])
        result.extend(replacement)
        cursor = end
    result.extend(lines[cursor:])
    out = "\n".join(result)
    return out + "\n" if had_nl else out


# --- reset (to HEAD baseline) ----------------------------------------------------

def reset_diffs(target_lines, baseline_lines, reset_selectors):
    """Reset-rule keys present in both trees whose value differs from the baseline.

    Yields (path, line_number, target_node, baseline_block_lines).
    """
    ttree = parse_block(target_lines, 0, len(target_lines), 0)
    btree = parse_block(baseline_lines, 0, len(baseline_lines), 0)
    found = []
    for selectors in reset_selectors:
        baseline_nodes = dict(collect(btree, selectors))
        for ident, tnode in collect(ttree, selectors):
            bnode = baseline_nodes.get(ident)
            if bnode is None:
                continue  # nothing in the repo to reset this to
            t_block = target_lines[tnode.start:tnode.end]
            b_block = baseline_lines[bnode.start:bnode.end]
            if t_block != b_block:
                found.append((render_path(ident), tnode.start + 1, tnode, b_block))
    return found


def reset_text(target_text, baseline_text_, reset_selectors):
    target_lines, had_nl = _split_lines(target_text)
    baseline_lines, _ = _split_lines(baseline_text_)
    ops = [(n.start, n.end, b) for _p, _ln, n, b in reset_diffs(target_lines, baseline_lines, reset_selectors)]
    return _apply_ops(target_lines, ops, had_nl)


# --- strip (delete dynamic content) ----------------------------------------------

def _strip_targets(tree, strip_rules):
    """Yield (container, child_node, path) for every strip-matched child."""
    for _action, selectors in strip_rules:
        container_sels, key_sel = selectors[:-1], selectors[-1]
        if container_sels:
            containers = collect(tree, container_sels)
        else:
            containers = [((), _Root(tree))]
        for ident, container in containers:
            cpath = render_path(ident)
            for child in container.children:
                if sel_match(child, key_sel):
                    label = child.key if child.kind == "map" else child.name
                    path = f"{cpath}/{label}" if cpath else (label or "*")
                    yield container, child, path


def _rebuild_ops(lines, container, removed):
    """Splice ops that drop ``removed`` children, relocating the list dash if needed."""
    if isinstance(container, _Root):
        return [(c.start, c.end, []) for c in removed]
    removed_ids = {id(c) for c in removed}
    kept = [c for c in container.children if id(c) not in removed_ids]
    out = []
    if container.kind == "item":
        for i, c in enumerate(kept):
            block = lines[c.start:c.end]
            if i == 0 and c.start != container.start:
                out.append(" " * container.indent + "- " + block[0].lstrip(" "))
                out.extend(block[1:])
            else:
                out.extend(block)
    else:  # mapping container: keep its own header line(s), then kept children
        header_end = container.children[0].start if container.children else container.end
        out.extend(lines[container.start:header_end])
        for c in kept:
            out.extend(lines[c.start:c.end])
    return [(container.start, container.end, out)]


def strip_text(text, strip_rules):
    lines, had_nl = _split_lines(text)
    tree = parse_block(lines, 0, len(lines), 0)
    by_container = {}
    for container, child, _path in _strip_targets(tree, strip_rules):
        by_container.setdefault(id(container), (container, []))[1].append(child)
    ops = []
    for container, removed in by_container.values():
        ops.extend(_rebuild_ops(lines, container, removed))
    return _apply_ops(lines, ops, had_nl)


def strip_hits(lines, strip_rules):
    tree = parse_block(lines, 0, len(lines), 0)
    return [(path, child.start + 1) for _c, child, path in _strip_targets(tree, strip_rules)]


# --- git baseline ----------------------------------------------------------------

def baseline_text(path, rev="HEAD"):
    """The ``rev`` version of ``path`` from git, or None if unavailable/new file."""
    p = Path(path).resolve()
    try:
        root = subprocess.run(
            ["git", "-C", str(p.parent), "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        rel = p.relative_to(root).as_posix()
        show = subprocess.run(["git", "-C", root, "show", f"{rev}:{rel}"], capture_output=True)
    except (subprocess.CalledProcessError, ValueError):
        return None
    if show.returncode != 0:
        return None
    return show.stdout.decode("utf-8")


# --- modes -----------------------------------------------------------------------

def _partition(rules):
    reset = [sels for action, sels in rules if action == "reset"]
    strip = [r for r in rules if r[0] == "strip"]
    return reset, strip


def check_file(path, rules):
    reset_selectors, strip_rules = _partition(rules)
    p = Path(path)
    if not p.is_file():
        print(f"skipped {path} (not found)", file=sys.stderr)
        return 0
    lines, _ = _split_lines(p.read_text(encoding="utf-8"))
    count = 0
    for label, lineno in sorted(strip_hits(lines, strip_rules), key=lambda h: h[1]):
        print(f"{path}:{lineno}: dynamic rviz entry '{label}' must not be committed")
        count += 1
    base = baseline_text(path)
    if base is not None:
        baseline_lines, _ = _split_lines(base)
        drifts = reset_diffs(lines, baseline_lines, reset_selectors)
        for rule_path, lineno, _n, _b in sorted(drifts, key=lambda d: d[1]):
            print(f"{path}:{lineno}: volatile rviz entry '{rule_path}' differs from committed value")
            count += 1
    return count


def write_file(path, rules):
    reset_selectors, strip_rules = _partition(rules)
    p = Path(path)
    if not p.is_file():
        print(f"skipped {path} (not found)", file=sys.stderr)
        return False
    original = p.read_text(encoding="utf-8")
    result = strip_text(original, strip_rules)
    base = baseline_text(path)
    if base is not None:
        result = reset_text(result, base, reset_selectors)
    if result != original:
        p.write_text(result, encoding="utf-8")
        return True
    return False


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true", help="report blacklisted state, exit non-zero if any")
    group.add_argument("--write", action="store_true", help="reset/strip blacklisted state in place")
    parser.add_argument("files", nargs="+")
    args = parser.parse_args(argv)

    rules = load_blacklist()

    if args.check:
        total = sum(check_file(f, rules) for f in args.files)
        if total:
            print(
                "\nRun tools/clean_rviz_configs.sh to reset/strip these, then re-stage. "
                "To commit as-is anyway: git commit --no-verify"
            )
            return 1
        return 0

    for f in args.files:
        if write_file(f, rules):
            print(f"cleaned {f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
