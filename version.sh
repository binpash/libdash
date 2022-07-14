#!/bin/sh

OPAM_VERSION=$(grep -e '^version:' libdash.opam | cut -d':' -f2 | tr -d ' "')

PYTHON_VERSION=$(grep -e '^version =' pyproject.toml | cut -d'=' -f2 | tr -d ' "')

[ "$OPAM_VERSION" = "$PYTHON_VERSION" ] && echo "$OPAM_VERSION" && exit 0

echo "Version numbers don't match!"
echo "  OPAM   is '$OPAM_VERSION'"
echo "  Python is '$PYTHON_VERSION'"
exit 1
