#!/usr/bin/env bash
set -euo pipefail

VERIFY_DIR=$(mktemp -d "${TMPDIR:-/tmp}/sdd-swarm-golden.XXXXXX")
trap 'rm -rf "$VERIFY_DIR"' EXIT INT TERM

mvn -B -o -q test
javac -cp target/classes -d "$VERIFY_DIR" .sdd-swarm/GoldenVerifier.java
java -cp "target/classes:$VERIFY_DIR" GoldenVerifier
