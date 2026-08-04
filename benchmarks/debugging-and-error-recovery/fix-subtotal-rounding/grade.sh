#!/usr/bin/env bash

set -euo pipefail

workspace="${1:?workspace path is required}"
node "$workspace/benchmark-app/invoice.test.js"
