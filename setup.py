from setuptools import setup
from setuptools.command.build_py import build_py

import os
import platform
import shutil
import subprocess
import sys

from pathlib import Path
long_description = (Path(__file__).parent / "README.md").read_text()

def try_exec(*cmds):
    proc = subprocess.run(cmds)

    if proc.returncode != 0:
        print('`{}` failed'.format(' '.join(cmds)), file=sys.stderr)
        proc.check_returncode()

class libdash_build_py(build_py):
    def run(self):
        build_py.run(self)

        if sys.platform == 'darwin':
            libtoolize = "glibtoolize"

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
        else:
            libtoolize = "libtoolize"

        # cibuildwheel builds every wheel in the same source tree; objects
        # left over from a previous build may target a different arch
        if os.path.exists('Makefile'):
            subprocess.run(['make', 'distclean'])

        try_exec(libtoolize)
        try_exec('aclocal')
        try_exec('autoheader')
        try_exec('automake', '--add-missing')
        try_exec('autoconf')
        try_exec('./configure')
        try_exec('make')

        shutil.copy2('src/.libs/dlldash.so', os.path.join(self.build_lib, 'libdash/libdash.so'))
        if sys.platform == 'darwin':
            shutil.copy2('src/.libs/libdash.dylib', os.path.join(self.build_lib, 'libdash/libdash.dylib'))

setup(name='libdash',
      packages=['libdash'],
      cmdclass={'build_py': libdash_build_py},
      version='0.5.0',
      long_description=long_description,
      long_description_content_type='text/markdown',
      include_package_data=True,
      has_ext_modules=lambda: True)
