from setuptools import setup
from setuptools.command.build_py import build_py

import shutil
import subprocess
import sys

def try_exec(*cmds):
    proc = subprocess.run(cmds)
    
    if proc.returncode != 0:
        print(f'`{cmds.join(" ")}` failed', file=sys.stderr)
        proc.check_returncode()

class libdash_build_py(build_py):
    def run(self):
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

        shutil.copy2('src/.libs/dlldash.so', 'libdash/libdash.so')
        if sys.platform == 'darwin':
            shutil.copy2('src/.libs/libdash.dylib', 'libdash/libdash.dylib')
        
        build_py.run(self)

setup(name='libdash',
      packages=['libdash'],
      cmdclass={'build_py': libdash_build_py})
