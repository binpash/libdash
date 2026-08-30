#!/usr/bin/env python3
"""Dump the parser nodes libdash detects in a script.

Per node: attributed line range, source lines, printed form, and the AST (-a).

Also audits attribution across nodes, reporting OVERLAP (range runs into the
next node), GAP (lines belong to no node), EMPTY, INVERTED, OVERRUN and
UNCOVERED. Exits nonzero on any, so it doubles as a regression test.
"""

import argparse
import os
import pprint
import sys

try:
    import libdash
except ModuleNotFoundError:
    # fall back to the working tree, so libdash/*.py edits need no reinstall
    sys.path.insert (0, os.path.dirname (os.path.dirname (os.path.abspath (__file__))))
    import libdash

sys.setrecursionlimit (9001)


class Problem:
    def __init__ (self, kind, index, detail):
        self.kind = kind
        self.index = index
        self.detail = detail

    def __str__ (self):
        return "{}: node {}: {}".format (self.kind, self.index, self.detail)


def read_lines (path):
    with open (path, 'r') as fp:
        return fp.readlines ()


def collect (path, init):
    """Parse `path`, returning (nodes, error) where nodes is a list of
    (ast, lines, linno_before, linno_after)."""
    nodes = []

    try:
        for node in libdash.parse (path, init):
            nodes.append (node)
    except Exception as e:
        return (nodes, e)

    return (nodes, None)


def is_inert (line):
    """A blank line or a whole-line comment yields no node, so it may legitimately
    fall between two nodes."""
    stripped = line.strip ()
    return stripped == "" or stripped.startswith ("#")


def audit (nodes, lines):
    """Check the line ranges the parser handed back for overlaps and gaps."""
    problems = []
    prev_after = 0

    for (i, (_ast, _text, before, after)) in enumerate (nodes):
        if after < before:
            problems.append (Problem ("INVERTED", i,
                                      "range [{}, {}) runs backwards".format (before, after)))
        elif after == before:
            problems.append (Problem ("EMPTY", i,
                                      "range [{}, {}) covers no lines".format (before, after)))

        if before < prev_after:
            problems.append (Problem ("OVERLAP", i,
                                      "starts at line {} but the previous node ran through line {}"
                                      .format (before, prev_after - 1)))
        elif before > prev_after:
            # Blank lines and comments produce no node, so only flag a gap that
            # swallowed something the parser should have accounted for.
            skipped = lines [prev_after:before]

            if not all (is_inert (line) for line in skipped):
                problems.append (Problem ("GAP", i,
                                          "lines {}..{} belong to no node: {}"
                                          .format (prev_after + 1, before,
                                                   ", ".join (repr (l) for l in skipped
                                                              if not is_inert (l)))))

        prev_after = max (prev_after, after)

    if nodes and prev_after > len (lines):
        problems.append (Problem ("OVERRUN", len (nodes) - 1,
                                  "last node ends at line {} but the file has {} lines"
                                  .format (prev_after, len (lines))))

    trailing = lines [prev_after:]

    if nodes and not all (is_inert (line) for line in trailing):
        problems.append (Problem ("UNCOVERED", len (nodes) - 1,
                                  "lines {}..{} after the last node belong to no node: {}"
                                  .format (prev_after + 1, len (lines),
                                           ", ".join (repr (l) for l in trailing
                                                      if not is_inert (l)))))

    return problems


def show (path, nodes, err, problems, args):
    lines = read_lines (path)

    print ("=== {} ({} lines) ===".format (path, len (lines)))

    for (i, (ast, text, before, after)) in enumerate (nodes):
        print ("--- node {}  lines [{}, {})  {}"
               .format (i, before, after,
                        "src lines {}..{}".format (before + 1, after) if after > before
                        else "no source lines"))

        if text is None:
            print ("    src   | <stdin: not captured>")
        else:
            for (n, line) in enumerate (text.splitlines ()):
                print ("    src   | {:>4} | {}".format (before + n + 1, line))

        for line in libdash.to_string (ast).splitlines ():
            print ("    print | {}".format (line))

        if args.ast:
            for line in pprint.pformat (ast, width = 100).splitlines ():
                print ("    ast   | {}".format (line))

    if err is not None:
        print ("!!! {}: {}".format (type (err).__name__, err))

    for p in problems:
        print ("!!! {}".format (p))

    print ("--- {} node(s), {} problem(s)".format (len (nodes), len (problems)))
    print ()


def show_ranges (path, nodes, err):
    """One line per node, stable enough to diff against a golden file."""
    for (i, (_ast, text, before, after)) in enumerate (nodes):
        print ("node {}  [{}, {})  {!r}".format (i, before, after, text))

    if err is not None:
        print ("error {}: {}".format (type (err).__name__, err))


def main ():
    ap = argparse.ArgumentParser (description = __doc__,
                                  formatter_class = argparse.RawDescriptionHelpFormatter)
    ap.add_argument ("files", nargs = "*", help = "shell scripts to dump")
    ap.add_argument ("-a", "--ast", action = "store_true",
                     help = "also dump the raw AST for each node")
    ap.add_argument ("-q", "--quiet", action = "store_true",
                     help = "only show files with problems")
    ap.add_argument ("-r", "--ranges", action = "store_true",
                     help = "terse one-line-per-node output, for golden-file comparison")
    ap.add_argument ("-w", "--which", action = "store_true",
                     help = "print which libdash was imported, then exit")
    args = ap.parse_args ()

    if args.which:
        print (libdash.__file__)
        return 0

    if not args.files:
        ap.error ("no files given")

    init = True
    bad = 0

    for path in args.files:
        try:
            lines = read_lines (path)
        except OSError as e:
            print ("=== {}: cannot read: {}".format (path, e))
            bad += 1
            continue

        (nodes, err) = collect (path, init)
        init = False

        if args.ranges:
            show_ranges (path, nodes, err)
            continue

        problems = audit (nodes, lines)

        if problems:
            bad += 1

        if problems or not args.quiet:
            show (path, nodes, err, problems, args)
        elif err is not None:
            print ("=== {}: {}: {}".format (path, type (err).__name__, err))
            print ()

    if bad:
        print ("{} file(s) with line-attribution problems".format (bad))

    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit (main ())
