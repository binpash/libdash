from setuptools import Extension, setup
from setuptools.command.build_ext import build_ext

import os
import platform
import shutil
import subprocess
import sys

from pathlib import Path

HERE = Path(__file__).parent.resolve()
long_description = (HERE / "README.md").read_text()

# What autotools needs to build the library.
SOURCES = ['configure.ac', 'Makefile.am', 'src']


def git_lines(*args):
    """The NUL-separated output of `git args` (which must include -z) in
    HERE, or None if HERE isn't the top of a git work tree (e.g., an
    unpacked sdist)."""
    try:
        top = subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=HERE,
                             capture_output=True, text=True)
        if top.returncode != 0 or Path(top.stdout.strip()).resolve() != HERE:
            return None
        out = subprocess.run(['git', *args], cwd=HERE,
                             capture_output=True, text=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        return None
    return [line for line in out.stdout.split('\0') if line]


def source_files():
    """The files under SOURCES, relative to HERE.

    In a git checkout, exactly the tracked files, so that leftovers from an
    in-tree build (e.g., a stale src/builtins.h) can never reach the build.
    In an sdist, everything: MANIFEST.in chose what to pack."""
    tracked = git_lines('ls-files', '-z', '--', *SOURCES)
    if tracked is None:
        return [str(f.relative_to(HERE))
                for d in SOURCES
                for f in ([HERE / d] if (HERE / d).is_file() else (HERE / d).rglob('*'))
                if f.is_file()]

    leftovers = git_lines('ls-files', '-z', '--others', '--', *SOURCES)
    if leftovers:
        print(f'warning: ignoring {len(leftovers)} untracked file(s) in the source tree, '
              'e.g., from an in-tree build (`git clean -fdX src` removes them):',
              file=sys.stderr)
        for f in leftovers[:10]:
            print(f'  {f}', file=sys.stderr)
        if len(leftovers) > 10:
            print(f'  ... and {len(leftovers) - 10} more', file=sys.stderr)
    return tracked


def try_exec(*cmds, cwd):
    proc = subprocess.run(cmds, cwd=cwd)

    if proc.returncode != 0:
        print('`{}` failed'.format(' '.join(cmds)), file=sys.stderr)
        proc.check_returncode()


class AutotoolsLibrary(Extension):
    """libdash's shared library, built by autotools and loaded with ctypes
    (it is not a Python extension module)."""

    def __init__(self, name):
        super().__init__(name, sources=[])


class libdash_build_ext(build_ext):
    """Builds the library in a copy of the C sources under build_temp, so that
    autoreconf, configure, and make never write into the source tree."""

    def run(self):
        self.build_autotools()

    def package_dir(self):
        # in place (e.g., editable installs): next to the Python sources
        return HERE / 'libdash' if self.inplace else Path(self.build_lib) / 'libdash'

    def library_names(self):
        names = ['libdash.so']
        if sys.platform == 'darwin':
            names.append('libdash.dylib')
        return names

    def get_outputs(self):
        return [str(self.package_dir() / name) for name in self.library_names()]

    def get_output_mapping(self):
        return {}

    def build_autotools(self):
        if sys.platform == 'darwin':
            target_arch = os.environ.get("ARCHFLAGS")
            build_arch = platform.machine()
            if not target_arch:
                target_arch = f"-arch {build_arch}"
                os.environ["ARCHFLAGS"] = target_arch
            if build_arch not in target_arch and "MACOSX_DEPLOYMENT_TARGET" not in os.environ:
                os.environ["MACOSX_DEPLOYMENT_TARGET"] = "11.0"

            # configure reads CFLAGS/LDFLAGS, not CCFLAGS; an explicit CFLAGS
            # replaces autoconf's default -g -O2, so keep it
            os.environ["CFLAGS"] = f'{os.environ.get("CFLAGS", "-g -O2")} {target_arch}'
            os.environ["LDFLAGS"] = f'{os.environ.get("LDFLAGS", "")} {target_arch}'.strip()

            print(f'ARCHFLAGS: {target_arch} MACOSX_DEPLOYMENT_TARGET: {os.environ.get("MACOSX_DEPLOYMENT_TARGET", "")} CFLAGS: {os.environ.get("CFLAGS")} LDFLAGS: {os.environ.get("LDFLAGS")}')

        # A fresh copy every time: cibuildwheel builds every wheel from the
        # same source tree, and objects from a previous build may target a
        # different arch.
        work = Path(self.build_temp).resolve() / 'autotools'
        if work.exists():
            shutil.rmtree(work)
        work.mkdir(parents=True)

        for f in source_files():
            (work / f).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(HERE / f, work / f)

        try_exec('autoreconf', '--install', '--force', cwd=work)
        try_exec('./configure', cwd=work)
        try_exec('make', cwd=work)

        dest = self.package_dir()
        dest.mkdir(parents=True, exist_ok=True)
        shutil.copy2(work / 'src/.libs/dlldash.so', dest / 'libdash.so')
        if sys.platform == 'darwin':
            shutil.copy2(work / 'src/.libs/libdash.dylib', dest / 'libdash.dylib')


setup(name='libdash',
      packages=['libdash'],
      ext_modules=[AutotoolsLibrary('libdash.libdash')],
      cmdclass={'build_ext': libdash_build_ext},
      version='0.5.2',
      long_description=long_description,
      long_description_content_type='text/markdown',
      include_package_data=True)
