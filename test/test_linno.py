#!/usr/bin/env python3
"""Line numbers on AST nodes. See ocaml/tests/test_linno.ml for the OCaml side.

Every node that carries a linno (Command, Redir, Background, Subshell, For,
Case, Defun) should report the line its construct starts on. Each case lists
those nodes in source (pre-)order, as (kind, linno).

Background is the regression: `cmd &` wraps any command that is not already
an NPIPE or NREDIR in a fresh nredir (list() in src/parser.c) and never set
its linno, so it reported whatever was on dash's stack: 0 in a fresh process,
garbage later.
"""

import os
import tempfile
import unittest

import libdash

KINDS = ("Command", "Redir", "Background", "Subshell", "For", "Case", "Defun")

_initialized = False


def parse(text):
    """Parse `text`, returning the list of top-level ASTs."""
    global _initialized
    fd, path = tempfile.mkstemp(suffix=".sh")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
        asts = [ast for (ast, _, _, _) in libdash.parse(path, not _initialized)]
        _initialized = True
        return asts
    finally:
        os.unlink(path)


def linnos(ast):
    """(kind, linno) for every linno-carrying node, in pre-order. Descends
    into words too, so command substitutions are covered."""
    out = []

    def walk(x):
        if isinstance(x, dict):
            for v in x.values():
                walk(v)
        elif isinstance(x, list):
            if len(x) == 2 and isinstance(x[0], str) and x[0] in KINDS:
                out.append((x[0], x[1][0]))
            for y in x:
                walk(y)

    walk(ast)
    return out


def filler(n):
    return "".join("echo %d\n" % i for i in range(1, n + 1))


def C(l): return ("Command", l)
def R(l): return ("Redir", l)
def BG(l): return ("Background", l)
def S(l): return ("Subshell", l)
def F(l): return ("For", l)
def K(l): return ("Case", l)
def D(l): return ("Defun", l)


CASES = {
    # constructs that already got the right linno
    "simple": ("echo a\necho b\n", [C(1), C(2)]),
    "semi": ("a; b\nc\n", [C(1), C(1), C(2)]),
    "continuation": ("echo a \\\n  b\necho c\n", [C(1), C(3)]),
    "comments": ("# c\n\necho a # trailing\n\n# c\necho b\n", [C(3), C(6)]),
    "pipe": ("a |\n  b\n", [C(1), C(2)]),
    "if": ("if true\nthen\n  echo y\nelse\n  echo n\nfi\n", [C(1), C(3), C(5)]),
    "for": ("for x in a b\ndo\n  echo $x\ndone\n", [F(1), C(3)]),
    "case": ("case $x in\n  a) echo a ;;\n  b)\n    echo b ;;\nesac\n",
             [K(1), C(2), C(4)]),
    "defun": ("f() {\n  echo f\n}\ng()\n{\n  echo g\n}\n",
              [D(1), C(2), D(4), C(6)]),
    "subshell": ("(\n  echo a\n)\n", [S(1), C(2)]),
    "redir": ("{\n  echo a\n} >/dev/null\nwhile true\ndo echo w\ndone 2>&1\n",
              [R(1), C(2), R(4), C(4), C(5)]),
    "heredoc": ("cat <<EOF\nx\ny\nEOF\necho after\n", [C(1), C(5)]),
    "cmdsubst": ("echo $(\n  echo inner\n)\necho after\n", [C(1), C(2), C(4)]),
    "backquote": ("echo `echo inner`\n", [C(1), C(1)]),

    # Background (the regression)
    "bg_first_line": ("sleep 1 &\n", [BG(1), C(1)]),
    # the reproduction from the bug report: garbage (e.g., 32601) here
    "bg_after_30_lines": (filler(30) + "sleep 1 &\n",
                          [C(i) for i in range(1, 31)] + [BG(31), C(31)]),
    # the wrapped NAND has no linno of its own
    "bg_and_list": ("a && b &\n", [BG(1), C(1), C(1)]),
    "bg_brace_group": ("echo 1\n{\n  echo a\n  echo b\n} &\n",
                       [C(1), BG(2), C(3), C(4)]),
    "bg_subshell": ("( echo a ) &\n", [BG(1), S(1), C(1)]),
    "bg_two_on_one_line": ("a & b &\n", [BG(1), C(1), BG(1), C(1)]),
    "bg_in_function": ("f() {\n  sleep 1 &\n}\n", [D(1), BG(2), C(2)]),
    # an NREDIR keeps its own linno; this already worked
    "bg_already_nredir": ("{ echo a; } >/dev/null &\n", [BG(1), C(1)]),
}


class Linno(unittest.TestCase):
    pass


def make_test(text, expected):
    def test(self):
        got = [x for ast in parse(text) for x in linnos(ast)]
        self.assertEqual(got, expected, "script:\n" + text)
    return test


for _name, (_text, _expected) in CASES.items():
    setattr(Linno, "test_" + _name, make_test(_text, _expected))


if __name__ == "__main__":
    unittest.main()
