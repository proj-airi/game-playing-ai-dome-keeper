#!/usr/bin/env node
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import ts from 'typescript'
import { convertGdToTs, resolveRegistry } from 'typescript-to-gdscript'

if (!process.argv[2])
  throw new Error('Usage: node scripts/generate-domekeeper-typings.ts <decompiled-project>')

const gameRoot = path.resolve(process.argv[2]!)
const outputFile = path.resolve(import.meta.dirname, '../mods/LemonNekoGH-DataCollectorAI/src/_typings/domekeeper.generated.d.ts')

const gdFiles: string[] = []
function walk(dir: string) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const filePath = path.join(dir, entry.name)
    if (entry.isDirectory())
      walk(filePath)
    else if (entry.name.endsWith('.gd'))
      gdFiles.push(filePath)
  }
}

walk(gameRoot)
const registry = resolveRegistry()
const targets = new Map<string, string | undefined>()

for (const filePath of gdFiles) {
  const source = readFileSync(filePath, 'utf8')
  if (/^\s*class_name\s+[A-Za-z_]\w*/m.test(source))
    targets.set(filePath, undefined)
}

const project = readFileSync(path.join(gameRoot, 'project.godot'), 'utf8')
for (const match of project.matchAll(/^([A-Za-z_]\w*)="\*?res:\/\/([^"]+)"$/gm)) {
  const resource = match[2]
  const relativeScript = resource.endsWith('.gd')
    ? resource
    : readFileSync(path.join(gameRoot, resource), 'utf8').match(/type="Script" path="res:\/\/([^"]+)"/)?.[1]
  if (relativeScript)
    targets.set(path.join(gameRoot, relativeScript), match[1])
}

const declarations: string[] = []
const autoloadTypes: Array<[string, string]> = []
for (const [filePath, autoloadName] of targets) {
  const source = readFileSync(filePath, 'utf8')
  const result = convertGdToTs({ source, filePath, registry, unsafeUseAny: true })
  const fixedSource = result.code.replace(/[A-Za-z_$][\w$]*:\s*: = \| null = [^,\n)]+/g, match => `${match.split(':', 1)[0]}?: any`)
  const emitted = ts.transpileDeclaration(fixedSource, {}).outputText
  const parsed = ts.createSourceFile('generated.d.ts', emitted, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS) as ts.SourceFile & { parseDiagnostics: ts.Diagnostic[] }
  const className = parsed.statements
    .find(ts.isClassDeclaration)
    ?.name
    ?.text
  if (!className || parsed.parseDiagnostics.length > 0)
    throw new Error(`typescript-to-gdscript emitted invalid declarations for ${filePath}`)

  declarations.push(emitted
    .replace(/^\s*export \{\};?\s*$/gm, '')
    .replace(/\bexport\s+declare\s+/g, '')
    .replace(/\bdeclare\s+/g, '')
    .replace(/\bexport\s+/g, ''))
  if (autoloadName)
    autoloadTypes.push([autoloadName, className])
}

mkdirSync(path.dirname(outputFile), { recursive: true })
writeFileSync(outputFile, [
  '// AUTO-GENERATED from the local decompiled Dome Keeper project. Do not commit.',
  'export {};',
  '',
  'declare global {',
  declarations.join('\n'),
  '',
  ...autoloadTypes
    .filter(([name, type]) => name !== type)
    .map(([name, type]) => `  const ${name}: ${type} & typeof ${type};`),
  '}',
  '',
].join('\n'))

console.log(`Generated ${declarations.length} Dome Keeper declarations at ${outputFile}`)
