#!/bin/sh

OPAM_VERSION=$(grep -e 'https://github.com/mgree/libdash/archive/' libdash.opam | sed -e 's/.*v\([0-9.]*\)\.tar\.gz"/\1/')

PYTHON_VERSION=$(grep -e '^version =' pyproject.toml | cut -d'=' -f2 | tr -d ' "')

PYTHON_VERSION2=$(grep -e 'version=' setup.py | cut -d'=' -f2 | tr -d "',")

[ "$OPAM_VERSION" = "$PYTHON_VERSION" ] && [ "$PYTHON_VERSION" = "$PYTHON_VERSION2" ] && echo "$OPAM_VERSION" && exit 0

echo "Version numbers don't match!"
echo "  OPAM   is '$OPAM_VERSION'"
echo "  Python is '$PYTHON_VERSION' in pyproject.toml"
echo "  Python is '$PYTHON_VERSION2' in setup.py"
exit 1
