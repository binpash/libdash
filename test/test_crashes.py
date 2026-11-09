#!/usr/bin/env python3
"""libdash's exported C entry points must report errors, not crash.
See ocaml/tests/test_crashes.ml for the OCaml side.

Each case runs in its own process (this file re-runs itself with the case's
name): a bad longjmp kills the process, and libdash keeps global state.

- parsecmd_safe installs its own jmploc as `handler` and must restore the
  caller's (possibly NULL) on return, so that a later sh_error (e.g., from
  setinputfile on a missing file) never longjmps into its dead frame.
- setalias_safe takes the alias name and value as two strings. Raw
  setalias(buf, val) wants buf = "name=value" with val pointing into it.
"""

import os
import subprocess
import sys
import tempfile
import unittest
from ctypes import CDLL, c_char_p, c_int, c_void_p

import libdash
from libdash._dash import initialize
from libdash.parser import libdash_library_path

MISSING = "/nonexistent/file"


def lib():
    return CDLL(libdash_library_path())


def script(text):
    fd, path = tempfile.mkstemp(suffix=".sh")
    with os.fdopen(fd, "w") as f:
        f.write(text)
    return path


def parse_one(text):
    asts = list(libdash.parse(script(text), init=False))
    assert len(asts) == 1, asts
    return libdash.to_string(asts[0][0])


def handler():
    return c_void_p.in_dll(lib(), "handler").value


def setalias_safe(name, value):
    f = lib().setalias_safe
    f.argtypes = [c_char_p, c_char_p]
    f.restype = c_int
    return f(name, value)


def expect_raise(f, *args):
    try:
        f(*args)
    except Exception:
        return
    raise AssertionError("expected an exception from %s%r" % (f.__name__, args))


# Each case starts in a fresh process with libdash initialized.

# errors outside a parse: parsecmd_safe must restore `handler`

def case_parsecmd_safe_restores_handler():
    before = handler()
    parse_one("echo hi\n")
    after = handler()
    assert before == after, "handler %r -> %r" % (before, after)


def case_missing_file_before_any_parse():
    expect_raise(lambda: list(libdash.parse(MISSING, init=False)))


def case_missing_file_after_a_parse():
    parse_one("echo hi\n")
    expect_raise(lambda: list(libdash.parse(MISSING, init=False)))


def case_parse_still_works_after_missing_file():
    expect_raise(lambda: list(libdash.parse(MISSING, init=False)))
    assert parse_one("echo hi\n") == "echo hi"


# setalias_safe takes the name and value as two strings

def case_setalias_safe():
    assert setalias_safe(b"ll", b"ls -l") == 0
    assert parse_one("ll\n") == "ls -l"


def case_setalias_safe_bad_name():
    assert setalias_safe(b"bad name", b"x") != 0
    assert setalias_safe(b"", b"x") != 0
    assert parse_one("echo hi\n") == "echo hi"


CASES = {name[len("case_"):]: f
         for name, f in globals().items() if name.startswith("case_")}


class Crashes(unittest.TestCase):
    pass


def make_test(name):
    def test(self):
        p = subprocess.run([sys.executable, __file__, name],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           universal_newlines=True, timeout=60)
        self.assertEqual(p.returncode, 0, "case %s exited %d; output:\n%s"
                         % (name, p.returncode, p.stdout))
    return test


for _name in CASES:
    setattr(Crashes, "test_" + _name, make_test(_name))


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] in CASES:
        initialize(lib())
        CASES[sys.argv[1]]()
    else:
        unittest.main()
