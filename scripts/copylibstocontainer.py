#!/usr/bin/env python3
"""Copy conan built shared libraries which are linked into any of the provided binaries to the provided directory"""

from auditwheel.lddtree import lddtree
from pathlib import Path


def find_conan_libs(binary: str):
    lddres = lddtree(binary)

    conan_libs = {lib: info for lib, info in lddres['libs'].items() if info['realpath'] and 'conan' in info['realpath']}

    return conan_libs


def unique_conan_libs(libs_dicts: list[dict]):
    lib_set = dict()
    for libs_dict in libs_dicts:
        for lib, info in libs_dict.items():
            if lib in lib_set and info != lib_set[lib]:
                raise RuntimeError(f'{lib} exists more than once with different information {info} and {lib_set[lib]}')
            elif lib not in lib_set:
                lib_set[lib] = info
    return lib_set


def main(binaries: list[str], dest: Path):
    from shutil import copyfile

    # Find the unique shared libraries which were build by conan
    ucl = unique_conan_libs([find_conan_libs(b) for b in binaries])

    # Copy those libraries to the destination
    for lib, info in ucl.items():
        copyfile(info['realpath'], dest.joinpath(lib))
    
    # ... the end? LD will find them at runtime?


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
    parser.add_argument('binary', type=str, nargs='+',
                        help="Binary (or binaries) to be checked for Conan shared library dependencies")

    args = parser.parse_args()

    main(args.binary, args.out)

