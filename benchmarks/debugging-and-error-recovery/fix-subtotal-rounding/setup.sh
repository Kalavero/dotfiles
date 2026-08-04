#!/usr/bin/env bash

set -euo pipefail

workspace="${1:?workspace path is required}"
mkdir -p "$workspace/benchmark-app"

cat > "$workspace/benchmark-app/invoice.js" <<'JS'
function subtotal(lineItems) {
  return lineItems.reduce((total, item) => total + Math.round(item.amount * 100) / 100, 0)
}

module.exports = { subtotal }
JS

cat > "$workspace/benchmark-app/invoice.test.js" <<'JS'
const assert = require('node:assert/strict')
const { subtotal } = require('./invoice')

assert.equal(subtotal([{ amount: 10.005 }, { amount: 10.005 }]), 20.01)
console.log('invoice subtotal test passed')
JS
