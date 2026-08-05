#!/usr/bin/env bash

set -euo pipefail

workspace="${1:?workspace path is required}"
mkdir -p "$workspace/benchmark-app"

cat > "$workspace/benchmark-app/locale.js" <<'JS'
let locale = 'en-US'

function getLocale() {
  return locale
}

function setLocale(value) {
  locale = value
}

module.exports = { getLocale, setLocale }
JS

cat > "$workspace/benchmark-app/run-tests.js" <<'JS'
const assert = require('node:assert/strict')
const { getLocale, setLocale } = require('./locale')

const tests = {
  'sets-portuguese-locale': () => {
    setLocale('pt-BR')
    assert.equal(getLocale(), 'pt-BR')
  },
  'default-locale': () => {
    assert.equal(getLocale(), 'en-US')
  },
}

const only = process.argv.includes('--only') ? process.argv[process.argv.indexOf('--only') + 1] : null
const seed = process.argv.includes('--seed') ? process.argv[process.argv.indexOf('--seed') + 1] : null
const names = only ? [only] : seed === '7' ? ['sets-portuguese-locale', 'default-locale'] : ['default-locale', 'sets-portuguese-locale']

for (const name of names) {
  tests[name]()
  console.log(`passed: ${name}`)
}
JS
