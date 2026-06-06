#!/bin/bash
# Run PulseDesk tests with Swift Testing framework
# Required because Command Line Tools needs explicit framework paths for the Testing module.

set -e
cd "$(dirname "$0")"

FRAMEWORKS_DIR="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
INTEROP_DIR="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

exec env \
  DYLD_FRAMEWORK_PATH="$FRAMEWORKS_DIR" \
  DYLD_LIBRARY_PATH="$INTEROP_DIR" \
  swift test \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS_DIR" \
    -Xlinker -F -Xlinker "$FRAMEWORKS_DIR" \
    -Xlinker -L -Xlinker "$INTEROP_DIR" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS_DIR" \
    -Xlinker -rpath -Xlinker "$INTEROP_DIR" \
    "$@"
