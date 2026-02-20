#!/bin/bash
# clawbridge – SCRIPTS/A_example.sh
# Smoke-Test: legt pro Aufruf eine leere Timestamp-Log-Datei an.

cd "$(dirname "$0")"
mkdir -p ./A_example
touch "./A_example/$(date '+%Y-%m-%d_%H-%M-%S').log"
