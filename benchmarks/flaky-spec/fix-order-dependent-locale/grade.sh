#!/usr/bin/env bash

set -euo pipefail

workspace="${1:?workspace path is required}"
node "$workspace/benchmark-app/run-tests.js" --only default-locale
node "$workspace/benchmark-app/run-tests.js" --seed 7
node "$workspace/benchmark-app/run-tests.js" --seed 1
