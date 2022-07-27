#!/usr/bin/env python3

import sys

import libdash

sys.setrecursionlimit (9001)

def print_asts(new_asts):
    for (ast, lines, linno_before, linno_after) in new_asts:
        print(libdash.to_string(ast))

if (len(sys.argv) == 1):
    new_asts = libdash.parse("-", True)
else:
    new_asts = libdash.parse(sys.argv[1], True)
    
print_asts(new_asts)
