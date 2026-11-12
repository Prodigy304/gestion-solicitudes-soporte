#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_OUT="$ROOT/target/classes"
TEST_OUT="$ROOT/target/test-classes"

rm -rf "$ROOT/target"
mkdir -p "$MAIN_OUT" "$TEST_OUT"

find "$ROOT/src/main/java" -name '*.java' -print > "$ROOT/target/main-sources.txt"
find "$ROOT/src/test/java" -name '*.java' -print > "$ROOT/target/test-sources.txt"

javac -encoding UTF-8 -d "$MAIN_OUT" @"$ROOT/target/main-sources.txt"
javac -encoding UTF-8 -cp "$MAIN_OUT" -d "$TEST_OUT" @"$ROOT/target/test-sources.txt"
java -ea -cp "$MAIN_OUT:$TEST_OUT" co.ias.soporte.service.SolicitudServiceTest
