import sys;

from parse_to_ast import parse_to_ast
from ast2shell import to_string

sys.setrecursionlimit (9001)

def print_asts(new_asts):
    for (ast, lines, linno_before, linno_after) in new_asts:
        print(to_string(ast))


if (len(sys.argv) == 1):
    new_asts = parse_to_ast("-", True)
else:
    new_asts = parse_to_ast(sys.argv[1], True)
    
print_asts(new_asts)
