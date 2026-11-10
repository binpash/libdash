#!/usr/bin/env python3
"""The ctypes mirrors in libdash/_dash.py against the C structs they copy.

_dash.py hand-copies dash's struct layouts, so a moved field is read at the
old offset and silently returns a different member. libdash.so carries a
table of the real sizes and offsets (libdash_struct_layout), and the bindings
compare it with _dash.LAYOUT before the first parse. The OCaml bindings need
no equivalent: ocaml/dune's ctypes stanza computes offsets at build time.
"""

import unittest

from ctypes import CDLL, POINTER, Structure, c_int, c_void_p

import libdash
from libdash import _dash
from libdash.parser import libdash_library_path


def lib():
    return CDLL(libdash_library_path())


def with_struct(ctype, fields):
    """_dash.LAYOUT, with `ctype`'s mirror replaced by one with `fields`."""
    out = []
    for (name, cls) in _dash.LAYOUT:
        if name == ctype:
            cls = type(cls.__name__, (Structure,), {"_fields_": fields})
        out.append((name, cls))
    return out


def fields_of(ctype):
    for (name, cls) in _dash.LAYOUT:
        if name == ctype:
            return list(cls._fields_)
    raise KeyError(ctype)


def mentioning(problems, *words):
    return [p for p in problems if all(w in p for w in words)]


class Layout(unittest.TestCase):
    def test_bindings_match_library(self):
        libdash.check_layout()
        self.assertEqual(_dash.layout_problems(lib(), _dash.LAYOUT), [])

    def test_moved_field(self):
        (type_, linno, *rest) = fields_of("struct ncmd")
        problems = _dash.layout_problems(lib(), with_struct("struct ncmd", [linno, type_, *rest]))
        self.assertTrue(mentioning(problems, "struct ncmd", "linno"), problems)
        self.assertTrue(mentioning(problems, "struct ncmd", "type"), problems)

    def test_field_missing_from_bindings(self):
        # a field the mirror lacks is reported by name, even when it moves no
        # other field and leaves the size alone (on 64-bit, eof sits in what
        # would otherwise be padding before nextc)
        fields = [f for f in fields_of("struct parsefile") if f[0] != "eof"]
        problems = _dash.layout_problems(lib(), with_struct("struct parsefile", fields))
        self.assertTrue(mentioning(problems, "struct parsefile", "eof"), problems)

    def test_field_unknown_to_library(self):
        fields = fields_of("struct nnot") + [("bogus", c_int)]
        problems = _dash.layout_problems(lib(), with_struct("struct nnot", fields))
        self.assertTrue(mentioning(problems, "struct nnot", "bogus"), problems)

    def test_wrong_size(self):
        fields = [("stackp", c_void_p), ("stacknxt", c_void_p)]
        problems = _dash.layout_problems(lib(), with_struct("struct stackmark", fields))
        self.assertTrue(mentioning(problems, "struct stackmark", "sizeof"), problems)

    def test_struct_missing_from_bindings(self):
        layout = [row for row in _dash.LAYOUT if row[0] != "struct nhere"]
        problems = _dash.layout_problems(lib(), layout)
        self.assertTrue(mentioning(problems, "struct nhere"), problems)

    def test_struct_unknown_to_library(self):
        class nbogus(Structure):
            _fields_ = [("type", c_int), ("next", POINTER(c_int))]
        layout = _dash.LAYOUT + [("struct nbogus", nbogus)]
        problems = _dash.layout_problems(lib(), layout)
        self.assertTrue(mentioning(problems, "struct nbogus"), problems)

    def test_initialize_refuses_mismatch(self):
        (type_, linno, *rest) = fields_of("struct ncmd")
        saved = (_dash.LAYOUT, _dash._layout_checked)
        try:
            _dash.LAYOUT = with_struct("struct ncmd", [linno, type_, *rest])
            _dash._layout_checked = False
            with self.assertRaises(_dash.LibdashLayoutError) as cm:
                _dash.initialize(lib())
            self.assertIn("struct ncmd", str(cm.exception))
            self.assertIs(libdash.LibdashLayoutError, _dash.LibdashLayoutError)
        finally:
            (_dash.LAYOUT, _dash._layout_checked) = saved


if __name__ == "__main__":
    unittest.main()
