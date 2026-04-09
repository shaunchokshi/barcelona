#!/bin/bash
# Patches for building on macOS 26 with Xcode 26.
# Run after package resolution, before building.
set -e

PKGS="Build/macOS/SourcePackages/checkouts"

echo "Patching GRDB.swift: add missing Darwin import..."
GRDB="$PKGS/GRDB.swift/GRDB/Core/StatementAuthorizer.swift"
if ! grep -q "^import Darwin" "$GRDB"; then
    python3 -c "
f = '$GRDB'
c = open(f).read()
open(f,'w').write('import Darwin\n' + c)
"
fi

echo "Patching Paris: move IMDMessageRecordRef typedef before first use..."
IMD="$PKGS/Paris/Sources/IMDPersistence/include/IMDPersistence.h"
python3 -c "
f = '$IMD'
c = open(f).read()
# Remove typedef from its original location
c = c.replace('typedef struct _IMDMessageRecordStruct *IMDMessageRecordRef;\n', '')
# Remove any prior bad patch
c = c.replace('typedef const void *IMDMessageRecordRef;\n', '')
# Insert correct typedef before first use
needle = 'CFStringRef IMDMessageRecordCopyGUID(CFAllocatorRef, IMDMessageRecordRef);'
if 'typedef struct _IMDMessageRecordStruct' not in c.split(needle)[0]:
    c = c.replace(needle, 'typedef struct _IMDMessageRecordStruct *IMDMessageRecordRef;\n' + needle)
open(f,'w').write(c)
"

echo "Patching sentry-cocoa: remove const from std::vector value types..."
SENTRY="$PKGS/sentry-cocoa/Sources/Sentry/SentryThreadMetadataCache.cpp"
python3 -c "
import re
f = '$SENTRY'
c = open(f).read()
c = re.sub(r'std::vector<const (\w+(?:::\w+)*)', r'std::vector<\1', c)
open(f,'w').write(c)
"

echo "All patches applied."
