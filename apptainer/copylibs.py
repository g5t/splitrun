#!/usr/bin/env python3
"""Copy conan built shared libraries which are linked into any of the provided binaries to the provided directory"""

# Last working auditwheel version v6.4.0
# Changes required from previous working version(s):
#	auditwheel.lddtree.lddtree -> auditwheel.lddtree.ldd
#	return value of lddtree() from dict -> auditwheel.lddtree.DynamicExecutable
#	library info from dict-entry 'libs' -> DynamicExecutable.libraries properties (type still dict)
#

from pathlib import Path

def auditwheel_version():
    from importlib.util import find_spec
    from importlib.metadata import version
    if find_spec('auditwheel') is None:
        raise RuntimeError('auditwheel is not installed!')
    return version('auditwheel')
    

def find_libs_old(binary: str, search: str):
    from auditwheel.lddtree import lddtree
    lddres = lddtree(binary)
    return {lib: info for lib, info in lddres['libs'].items() if info['realpath'] and search in info['realpath']}
    
    
def copy_libs_old(dest: Path, libs: dict[str, dict]):
    from shutil import copyfile
    for lib, info in libs.items():
        copyfile(info['realpath'], dest.joinpath(lib))
    

def find_libs_new(binary: str, search: str):
    from auditwheel.lddtree import ldd
    libs = ldd(binary).libraries
    return {lib: info for lib, info in libs.items() if search in info.realpath.as_posix()}
    
    
def copy_libs_new(dest: Path, libs: dict):
    from shutil import copyfile
    for lib, info in libs.items():
        copyfile(info.realpath, dest.joinpath(lib))
    

def unique_libs(libs_dicts: list[dict]):
    lib_set = dict()
    for libs_dict in libs_dicts:
        for lib, info in libs_dict.items():
            if lib in lib_set and info != lib_set[lib]:
                raise RuntimeError(f'{lib} exists more than once with different information {info} and {lib_set[lib]}')
            elif lib not in lib_set:
                lib_set[lib] = info
    return lib_set


def main(binaries: list[str], search: str, dest: Path):
    version = auditwheel_version()
    if version < '6.4.0':
        find, copy = find_libs_old, copy_libs_old
    elif version >= '6.4.0':
    	find, copy = find_libs_new, copy_libs_new
    else:
    	raise ValueError(f'Unhandled version {version}')

    # Find the unique shared libraries which were build by conan
    # Copy those libraries to the destination
    copy(dest, unique_libs([find(b, search) for b in binaries]))


def is_dir(arg):
    if not isinstance(arg, Path):
        arg = Path(arg)
    if not arg.is_dir():
        arg.mkdir(parents=True)
    return arg


if __name__ == '__main__':
    from argparse import ArgumentParser
    parser = ArgumentParser(prog='copylibstocontainer', description=__doc__)
    parser.add_argument('-o', '--out', type=is_dir, help="Output directory to copy libraries to")
    parser.add_argument('-d', '--dir', type=str, default='conan', help='Special path to copy from')
    parser.add_argument('binary', type=str, nargs='+',
                        help="Binary (or binaries) to be checked for Conan shared library dependencies")

    args = parser.parse_args()

    main(args.binary, args.dir, args.out)

