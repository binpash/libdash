# 0.5.3 (2026-11-10)

- Fix crashes when `sh_error` fires outside a parse (e.g., `setinputfile` on a missing file); add `setinputfile_safe` and `setalias_safe`. `Dash.setalias` works again (broken since 0.4.0).

- Set the line number on `Background` nodes, which held uninitialized memory.

- The Python bindings check their struct layouts against `libdash.so` before the first parse, raising `LibdashLayoutError` on a mismatch; `libdash.check_layout()` runs the check on demand.

- Fixed bugs in how both Python and OCaml bindings computed tilde prefixes.

- `pip install .` builds the library in setuptools' build directory and no longer writes autotools output into the source tree.

- Release tags drop the `v` prefix, starting with this one (`0.5.3`, not `v0.5.3`): libdash's history includes dash's, and dash's own release tags are `v0.5.3` and up.

# 0.5.2 (2026-09-22)

- Use `autoreconf` to handle libtoolize properly.

# 0.5.1 (2026-09-01)

- Fix multiline attribution bug.

- Many new tests to avoid regressions.

# 0.5.0 (2026-08-03)

- Add multibyte character support.

# 0.4.1 (2026-07-14)

- Bugfixes to OCaml bindings.

# 0.4.0 (2027-07-14)

- Rewrite history to include all prior dash history correctly.
- Fix CI on macOS.

# 0.3.1 (2022-08-23)

- Bugfix for parsing in heredocs.

# 0.3 (2022-07-28)

- Add Python bindings.

# 0.1.2 (2022-02-24)

- Update bindings to dash v0.5.11.5, bringing parser bugfixes.

# 0.1.1 (2020-05-12)

- Bugfixes re `popstackmark` from @tucak.

# 0.1 (2020-02-25)

- Initial release.
