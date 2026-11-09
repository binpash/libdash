#!/usr/bin/env python3
"""Tilde prefixes in the AST. See ocaml/tests/test_tilde.ml for the OCaml
side, which has the same cases and expected strings.

The bindings should match dash's own expansion (argstr and exptilde in
src/expand.c, and POSIX XCU 2.6.1):

- A tilde prefix starts only at the start of a word (arguments, redirection
  targets, the word in ${x:-word}) or, in an assignment, right after the
  first '=' or an unquoted ':'. Anywhere else '~' is an ordinary C '~'.
- The prefix runs to an unquoted '/' or the end of the word; in an
  assignment, an unquoted ':' also ends it.
- If a quote, escape, or expansion interrupts the prefix, there is no tilde
  prefix: the '~' and everything after it are ordinary characters.
"""

import os
import tempfile
import unittest

import libdash

_initialized = False


def parse_command(text):
    """Parse a one-command script, returning its Command fields."""
    global _initialized
    fd, path = tempfile.mkstemp(suffix=".sh")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text + "\n")
        asts = [ast for (ast, _, _, _) in libdash.parse(path, not _initialized)]
        _initialized = True
    finally:
        os.unlink(path)
    assert len(asts) == 1 and asts[0][0] == "Command", asts
    _linno, assigns, args, redirs = asts[0][1]
    return assigns, args, redirs


def show(word):
    """A compact, binding-neutral rendering of a word."""
    out = []
    for c in word:
        k = c[0]
        if k in ("C", "E"):
            out.append("%s '%s'" % (k, chr(c[1])))
        elif k == "T":
            out.append("T None" if c[1] == "None" else "T '%s'" % c[1][1])
        elif k == "Q":
            out.append("Q[%s]" % show(c[1]))
        elif k == "V":
            out.append("V %s[%s]" % (c[1][2], show(c[1][3])))
        elif k == "B":
            out.append("B")
        else:
            raise ValueError("unexpected arg char %r" % (c,))
    return ", ".join(out)


def word(kind, text):
    assigns, args, redirs = parse_command(text)
    if kind == "arg":       # the first argument after the command name
        return show(args[1])
    if kind == "assign":    # the value of the first assignment
        return show(assigns[0][1])
    if kind == "redir":     # the target of the first redirection
        return show(redirs[0][1][2])
    raise ValueError(kind)


# name: (kind, script, expected word)
CASES = {
    # tilde prefixes
    "bare": ("arg", "echo ~", "T None"),
    "home_slash": ("arg", "echo ~/a", "T None, C '/', C 'a'"),
    "user_slash": ("arg", "echo ~ab/d", "T 'ab', C '/', C 'd'"),
    "double_quoted": ("arg", 'echo "~"', "Q[E '~']"),
    "escaped": ("arg", "echo \\~", "E '~'"),
    "assign_start": ("assign", "x=~/a", "T None, C '/', C 'a'"),
    "assign_after_colon": ("assign", "x=a:~/b", "C 'a', C ':', T None, C '/', C 'b'"),
    "assign_colon_ends_prefix": ("assign", "x=~a:b", "T 'a', C ':', C 'b'"),
    "assign_two_colons": ("assign", "x=~a:~/c", "T 'a', C ':', T None, C '/', C 'c'"),
    "var_word": ("arg", "echo ${x:-~/a}", "V x[T None, C '/', C 'a']"),
    "redir_target": ("redir", "echo >~/f", "T None, C '/', C 'f'"),

    # an interrupted prefix is no prefix, and keeps its characters
    "interrupted_by_escape": ("arg", "echo ~ab\\c", "C '~', C 'a', C 'b', E 'c'"),
    "interrupted_by_quote": ("arg", 'echo ~ab"c"', "C '~', C 'a', C 'b', Q[C 'c']"),
    "interrupted_by_var": ("arg", "echo ~ab$x", "C '~', C 'a', C 'b', V x[]"),
    "interrupted_by_backquote": ("arg", "echo ~ab`c`", "C '~', C 'a', C 'b', B"),
    "interrupted_right_away": ("arg", "echo ~\\c", "C '~', E 'c'"),
    "interrupted_in_assign": ("assign", "x=~ab\\c", "C '~', C 'a', C 'b', E 'c'"),

    # a tilde prefix only at the start of a word (or after = and : in an
    # assignment)
    "mid_word": ("arg", "echo a~b", "C 'a', C '~', C 'b'"),
    "after_slash": ("arg", "echo ~/a~b", "T None, C '/', C 'a', C '~', C 'b'"),
    "after_colon_not_assign": ("arg", "echo a:~/b", "C 'a', C ':', C '~', C '/', C 'b'"),
    "mid_assign": ("assign", "x=a~b", "C 'a', C '~', C 'b'"),
    "mid_var_word": ("arg", "echo ${x:-a~b}", "V x[C 'a', C '~', C 'b']"),
    "mid_redir_target": ("redir", "echo >a~b", "C 'a', C '~', C 'b'"),

    # outside assignments, ':' is part of the prefix
    "colon_in_prefix": ("arg", "echo ~a:b", "T 'a:b'"),
}


class Tilde(unittest.TestCase):
    pass


def make_test(kind, text, expected):
    def test(self):
        self.assertEqual(word(kind, text), expected, "script: " + text)
    return test


for _name, (_kind, _text, _expected) in CASES.items():
    setattr(Tilde, "test_" + _name, make_test(_kind, _text, _expected))


if __name__ == "__main__":
    unittest.main()
