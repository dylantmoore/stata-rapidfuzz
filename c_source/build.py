#!/usr/bin/env python3
"""
Build rapidfuzz Stata plugin (C++ wrapping rapidfuzz-cpp headers).

Before building, download stplugin.h and stplugin.c from:
  https://www.stata.com/plugins/

Usage:
    python3 build.py              # Build for current platform
    python3 build.py --all        # Build for all platforms
    python3 build.py --debug      # Build with sanitizers
"""

import subprocess
import sys
import platform
import os

PLUGIN_NAME = "rapidfuzz_plugin"
CPP_SOURCE = "rapidfuzz_plugin.cpp"
C_SOURCE = "stplugin.c"
OUTPUT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Common C++ flags: C++17 required by rapidfuzz-cpp, -I. for vendored headers
CPP_STD = "-std=c++17"
INCLUDE = "-I."

PLATFORMS = {
    "macosx": {
        "cc": "gcc",
        "cxx": "g++",
        "cflags": "-O3 -fPIC -DSYSTEM=APPLEMAC -arch arm64",
        "cxxflags": f"{CPP_STD} -O3 -fPIC -DSYSTEM=APPLEMAC -arch arm64 {INCLUDE}",
        "ldflags": "-bundle -arch arm64",
    },
    "unix": {
        "cc": "gcc",
        "cxx": "g++",
        "cflags": "-O3 -fPIC -DSYSTEM=OPUNIX",
        "cxxflags": f"{CPP_STD} -O3 -fPIC -DSYSTEM=OPUNIX {INCLUDE}",
        "ldflags": "-shared",
    },
    "windows": {
        "cc": "x86_64-w64-mingw32-gcc",
        "cxx": "x86_64-w64-mingw32-g++",
        "cflags": "-O3 -DSYSTEM=STWIN32",
        "cxxflags": f"{CPP_STD} -O3 -DSYSTEM=STWIN32 {INCLUDE}",
        "ldflags": "-shared -static-libgcc -static-libstdc++",
    },
}


def detect_platform():
    system = platform.system()
    if system == "Darwin":
        return "macosx"
    if system == "Linux":
        return "unix"
    if system == "Windows":
        return "windows"
    return None


def check_sdk():
    for f in ["stplugin.h", "stplugin.c"]:
        if not os.path.exists(f):
            print(f"ERROR: {f} not found. Download from https://www.stata.com/plugins/")
            sys.exit(1)
    if not os.path.isdir("rapidfuzz"):
        print("ERROR: rapidfuzz/ headers not found. Run:")
        print("  git clone --depth 1 https://github.com/rapidfuzz/rapidfuzz-cpp.git tmp")
        print("  cp -r tmp/rapidfuzz . && rm -rf tmp")
        sys.exit(1)


def build(plat, debug=False):
    cfg = PLATFORMS[plat]
    output = os.path.join(OUTPUT_DIR, f"{PLUGIN_NAME}_{plat}.plugin")
    obj_c = "stplugin.o"
    obj_cpp = "rapidfuzz_plugin.o"

    cflags = cfg["cflags"]
    cxxflags = cfg["cxxflags"]
    if debug:
        cflags = cflags.replace("-O3", "-O0 -g -fsanitize=address")
        cxxflags = cxxflags.replace("-O3", "-O0 -g -fsanitize=address")

    print(f"Building {PLUGIN_NAME}_{plat}.plugin...")

    # Step 1: Compile stplugin.c as C
    cmd1 = f"{cfg['cc']} {cflags} -c {C_SOURCE} -o {obj_c}"
    print(f"  [C]   {cmd1}")
    r = subprocess.run(cmd1, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  FAILED: {r.stderr}")
        return False

    # Step 2: Compile plugin as C++17
    cmd2 = f"{cfg['cxx']} {cxxflags} -c {CPP_SOURCE} -o {obj_cpp}"
    print(f"  [C++] {cmd2}")
    r = subprocess.run(cmd2, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  FAILED: {r.stderr}")
        return False

    # Step 3: Link (quote output path for spaces)
    cmd3 = f"{cfg['cxx']} {cfg['ldflags']} {obj_c} {obj_cpp} -o \"{output}\""
    print(f"  [LD]  {cmd3}")
    r = subprocess.run(cmd3, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  FAILED: {r.stderr}")
        return False

    # Cleanup object files
    for f in [obj_c, obj_cpp]:
        if os.path.exists(f):
            os.remove(f)

    print(f"  OK -> {output}")
    return True


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    check_sdk()

    debug = "--debug" in sys.argv
    build_all = "--all" in sys.argv

    targets = list(PLATFORMS.keys()) if build_all else [detect_platform()]
    if targets[0] is None:
        print("Cannot detect platform. Use --all.")
        sys.exit(1)

    ok = all(build(t, debug) for t in targets)
    if ok:
        print(f"\nDone. Plugins in: {OUTPUT_DIR}")
    else:
        print("\nSome builds failed.")
        sys.exit(1)


if __name__ == "__main__":
    main()
