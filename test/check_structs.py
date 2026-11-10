#!/usr/bin/env python3
"""Check libdash/_dash.py's ctypes mirrors against dash's real C structs.

_dash.py hand-copies dash's struct layouts and nothing else verifies the copy,
so a moved field is read at the old offset and silently returns a different
member -- as happened when parsefile gained `eof` and Python's `lleft` started
returning it.

Compiles a probe against a configured tree's src/*.h (src/nodes.h and
config.h are generated) and compares sizeof and every field offset with
ctypes. The tree is, in order: $LIBDASH_BUILT_TREE; setuptools' build
directory from the latest `pip install .`, which built the library the Python
tests load; or the source tree, if built in place. (dune's _build keeps no
config.h.) A build directory holds the headers as of its last build, so
rebuild after changing src/*.h. With --require, a missing tree is an error,
not a skip.

The OCaml bindings need no equivalent: ocaml/dune's ctypes stanza computes
offsets from the headers at build time.
"""

import glob
import os
import subprocess
import sys
import tempfile

from ctypes import sizeof

ROOT = os.path.dirname (os.path.dirname (os.path.abspath (__file__)))
sys.path.insert (0, ROOT)

from libdash import _dash

# (python class, C type, check field offsets too?)
# stackmark is opaque in _dash.py -- only its size is claimed correct.
STRUCTS = [
    ("stackmark",  "struct stackmark",  False),
    ("nodelist",   "struct nodelist",   True),
    ("union_node", "union node",        True),
    ("ncmd",       "struct ncmd",       True),
    ("npipe",      "struct npipe",      True),
    ("nredir",     "struct nredir",     True),
    ("nbinary",    "struct nbinary",    True),
    ("nif",        "struct nif",        True),
    ("nfor",       "struct nfor",       True),
    ("ncase",      "struct ncase",      True),
    ("nclist",     "struct nclist",     True),
    ("ndefun",     "struct ndefun",     True),
    ("narg",       "struct narg",       True),
    ("nfile",      "struct nfile",      True),
    ("ndup",       "struct ndup",       True),
    ("nhere",      "struct nhere",      True),
    ("nnot",       "struct nnot",       True),
    ("strpush",    "struct strpush",    True),
    ("parsefile",  "struct parsefile",  True),
]

PROBE_HEADER = """\
#include <stddef.h>
#include <stdio.h>
#include "shell.h"
#include "nodes.h"
#include "input.h"
#include "memalloc.h"

int main (void)
{
"""


def probe_source (ctype, fields):
    body = ['    printf ("sizeof %zu\\n", sizeof ({}));'.format (ctype)]

    for name in fields:
        body.append ('    printf ("{0} %zu\\n", offsetof ({1}, {0}));'
                     .format (name, ctype))

    return PROBE_HEADER + "\n".join (body) + "\n    return 0;\n}\n"


def run_probe (ctype, fields, workdir, tree):
    """Returns (offsets dict, None) or (None, error string)."""
    src = os.path.join (workdir, "probe.c")
    exe = os.path.join (workdir, "probe")

    with open (src, "w") as f:
        f.write (probe_source (ctype, fields))

    cc = os.environ.get ("CC", "cc")
    compiled = subprocess.run ([cc, "-I", os.path.join (tree, "src"), "-I", tree,
                                "-o", exe, src],
                               capture_output = True, text = True)

    if compiled.returncode != 0:
        # a field C no longer has lands here, e.g. "no member named 'lastc'"
        notes = [l.strip () for l in compiled.stderr.splitlines () if "error:" in l]
        return (None, "; ".join (notes) or "probe failed to compile")

    ran = subprocess.run ([exe], capture_output = True, text = True)

    if ran.returncode != 0:
        return (None, "probe failed to run")

    out = {}

    for line in ran.stdout.split ("\n"):
        if line.strip ():
            (key, value) = line.rsplit (" ", 1)
            out [key] = int (value)

    return (out, None)


def resolve (pyname):
    """_dash.py's `def nodelist` shadows `class nodelist`; reach the class
    through a field pointing at it."""
    found = getattr (_dash, pyname)

    if pyname == "nodelist" and not hasattr (found, "_fields_"):
        return dict (_dash.narg._fields_) ["backquote"]._type_

    return found


def configured (tree):
    return all (os.path.exists (os.path.join (tree, f))
                for f in [os.path.join ("src", "nodes.h"), "config.h"])


def find_tree ():
    """A configured tree to compile against, or None."""
    if "LIBDASH_BUILT_TREE" in os.environ:
        tree = os.environ ["LIBDASH_BUILT_TREE"]
        return tree if configured (tree) else None

    # setuptools' build matches the library the Python tests load; newest
    # first. The source tree comes last: an in-tree build there may be stale.
    setuptools = sorted (glob.glob (os.path.join (ROOT, "build", "temp.*", "autotools")),
                         key = os.path.getmtime, reverse = True)

    for tree in setuptools + [ROOT]:
        if configured (tree):
            return tree

    return None


def main ():
    require = "--require" in sys.argv [1:]
    tree = find_tree ()

    if tree is None:
        print ("{}: no configured tree (src/nodes.h, config.h); build libdash first"
               .format ("FAIL" if require else "SKIP"))
        return 1 if require else 0

    print ("# headers: {}".format (os.path.relpath (tree, ROOT)))

    status = 0

    with tempfile.TemporaryDirectory () as workdir:
        for (pyname, ctype, check_fields) in STRUCTS:
            cls = resolve (pyname)
            fields = [n for (n, _t) in cls._fields_] if check_fields else []

            (c, err) = run_probe (ctype, fields, workdir, tree)

            if err is not None:
                print ("STRUCT_MISMATCH: '{}' ({}): {}".format (ctype, pyname, err))
                status = 1
                continue

            problems = []

            if sizeof (cls) != c ["sizeof"]:
                problems.append ("sizeof: python {}, C {}"
                                 .format (sizeof (cls), c ["sizeof"]))

            for name in fields:
                mine = getattr (cls, name).offset

                if mine != c [name]:
                    problems.append ("field {}: python offset {}, C offset {}"
                                     .format (name, mine, c [name]))

            if problems:
                for p in problems:
                    print ("STRUCT_MISMATCH: '{}' ({}): {}".format (ctype, pyname, p))
                status = 1
            else:
                print ("PASS '{}' (sizeof {}, {} field(s))"
                       .format (ctype, c ["sizeof"], len (fields)))

    return status


if __name__ == "__main__":
    sys.exit (main ())
