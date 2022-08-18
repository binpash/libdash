#!/bin/sh

PYTHON_VERSION=$(grep -e '^version =' pyproject.toml | cut -d'=' -f2 | tr -d ' "')

PYTHON_VERSION2=$(grep -e 'version=' setup.py | cut -d'=' -f2 | tr -d "',")

[ "$PYTHON_VERSION" = "$PYTHON_VERSION2" ] && echo "$PYTHON_VERSION" && exit 0

echo "Version numbers don't match!"
echo "  Python is '$PYTHON_VERSION' in pyproject.toml"
echo "  Python is '$PYTHON_VERSION2' in setup.py"
exit 1
