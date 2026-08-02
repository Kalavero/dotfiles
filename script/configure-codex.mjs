#!/usr/bin/env node

import fs from "node:fs"

const [target, candidate, model] = process.argv.slice(2)

if (!target || !candidate || !model) {
  console.error('Usage: configure-codex.mjs <target> <candidate> <model>')
  process.exit(2)
}

if (fs.existsSync(candidate)) fs.rmSync(candidate)

let content = fs.existsSync(target) ? fs.readFileSync(target, 'utf8') : ''
const marker = '# Managed by kalavero sync.sh'
const managedPattern = /(# Managed by kalavero sync\.sh\n\s*default_subagent_model\s*=\s*)["'][^"']*["']/m

if (managedPattern.test(content)) {
  content = content.replace(managedPattern, `$1"${model}"`)
  fs.writeFileSync(candidate, content)
  process.exit(0)
}

if (/^\s*(?:agents|["']agents["'])\.default_subagent_model\s*=/m.test(content)) process.exit(0)
if (/^\s*(?:agents|["']agents["'])\s*[.=]/m.test(content)) {
  console.error(`  Skipping Codex subagent default: ${target} uses a dotted or inline agents table`)
  process.exit(0)
}
if (/^\s*\[\[?\s*(?:agents|["']agents["'])\s*\./m.test(content)) {
  console.error(`  Skipping Codex subagent default: ${target} declares agent subtables without [agents]`)
  process.exit(0)
}

const lines = content.split('\n')
let agentsStart = -1
let agentsEnd = lines.length

for (let index = 0; index < lines.length; index += 1) {
  if (/^\s*\[\s*(?:agents|["']agents["'])\s*\]\s*(?:#.*)?$/.test(lines[index])) {
    agentsStart = index
    continue
  }

  if (agentsStart >= 0 && /^\s*\[.+\]\s*(?:#.*)?$/.test(lines[index])) {
    agentsEnd = index
    break
  }
}

if (agentsStart >= 0) {
  const hasModel = lines
    .slice(agentsStart + 1, agentsEnd)
    .some((line) => /^\s*(?:default_subagent_model|["']default_subagent_model["'])\s*=/.test(line))

  if (hasModel) process.exit(0)
  lines.splice(agentsStart + 1, 0, marker, `default_subagent_model = "${model}"`)
  content = lines.join('\n')
} else {
  content = `${content.trimEnd()}${content.trim() ? '\n\n' : ''}[agents]\n${marker}\ndefault_subagent_model = "${model}"\n`
}

fs.writeFileSync(candidate, content)
