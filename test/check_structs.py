#!/usr/bin/env python3
"""Check libdash/_dash.py's ctypes mirrors against dash's real C structs.

_dash.py hand-copies dash's struct layouts and nothing else verifies the copy,
so a moved field is read at the old offset and silently returns a different
member -- as happened when parsefile gained `eof` and Python's `lleft` started
returning it.

Compiles a probe against src/*.h and compares sizeof and every field offset
with ctypes. Needs a built tree (src/nodes.h is generated).

The OCaml bindings need no equivalent: ocaml/dune's ctypes stanza computes
offsets from the headers at build time.
"""

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


def run_probe (ctype, fields, workdir):
    """Returns (offsets dict, None) or (None, error string)."""
    src = os.path.join (workdir, "probe.c")
    exe = os.path.join (workdir, "probe")

    with open (src, "w") as f:
        f.write (probe_source (ctype, fields))

    cc = os.environ.get ("CC", "cc")
    compiled = subprocess.run ([cc, "-I", os.path.join (ROOT, "src"), "-I", ROOT,
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


def main ():
    if not os.path.exists (os.path.join (ROOT, "src", "nodes.h")):
        print ("SKIP: src/nodes.h not generated; build libdash first")
        return 0

    status = 0

    with tempfile.TemporaryDirectory () as workdir:
        for (pyname, ctype, check_fields) in STRUCTS:
            cls = resolve (pyname)
            fields = [n for (n, _t) in cls._fields_] if check_fields else []

            (c, err) = run_probe (ctype, fields, workdir)

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
