from setuptools import setup
from setuptools.command.build_py import build_py

import os
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
        else:
            libtoolize = "libtoolize"
        
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
      version='0.3.1',
      long_description=long_description,
      long_description_content_type='text/markdown',
      include_package_data=True,
      has_ext_modules=lambda: True)
