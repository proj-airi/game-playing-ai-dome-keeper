import { existsSync, readFileSync, realpathSync } from 'node:fs'
import { mkdir, readFile, writeFile } from 'node:fs/promises'

import { basename, dirname, isAbsolute, resolve } from 'node:path'
import { execa } from 'execa'
import ts from 'typescript'

export interface CompileTestFileOptions {
  sourcePath: string
  outputDirectory: string
  projectPath: string
}

const TEST_FILE_EXTENSION = /\.[cm]?tsx?$/
const TEST_API_MODULE = '@vidot/vitest'
const TSTOGD_CONFIG = 'tstogd.json'
const REGISTRATION_API_NAMES: readonly string[] = [
  'afterAll',
  'afterEach',
  'beforeAll',
  'beforeEach',
  'describe',
  'test',
]
const TEST_API_NAMES = [...REGISTRATION_API_NAMES, 'expect']

export async function compileTestFile(
  options: CompileTestFileOptions,
): Promise<string> {
  const sourcePath = resolve(options.sourcePath)
  const outputDirectory = resolve(options.outputDirectory)
  const projectPath = resolve(options.projectPath)
  const source = await readFile(sourcePath, 'utf8')
  const wrapper = transformTestModule(sourcePath, source)
  const stem = basename(sourcePath).replace(TEST_FILE_EXTENSION, '')
  const wrapperPath = resolve(outputDirectory, `${stem}.vidot.ts`)

  await mkdir(outputDirectory, { recursive: true })
  await writeFile(wrapperPath, wrapper)
  const testProgram = createTestProgram(sourcePath, wrapperPath)
  const externalPackages = readTestLibraries(sourcePath)
  const generatedConfigPath = resolve(outputDirectory, 'tsconfig.vidot.json')

  await writeFile(generatedConfigPath, `${JSON.stringify({
    extends: testProgram.configPath,
    files: testProgram.program.getRootFileNames(),
  }, null, 2)}\n`)
  await writeFile(resolve(outputDirectory, TSTOGD_CONFIG), `${JSON.stringify({
    tsDir: '.',
    gdDir: '.',
    typingsDir: '_typings',
    disableGodotLint: true,
    externalPackages,
  }, null, 2)}\n`)
  await execa('tstogd', [
    'convert',
    wrapperPath,
    '--project-root',
    projectPath,
    '--tsconfig',
    generatedConfigPath,
    '--no-check',
  ], { cwd: outputDirectory })

  const outputPath = wrapperPath.replace(TEST_FILE_EXTENSION, '.gd')
  if (!existsSync(outputPath))
    throw new Error(`tstogd did not compile ${sourcePath}`)

  return outputPath
}

function createTestProgram(
  sourcePath: string,
  wrapperPath: string,
): { configPath: string, program: ts.Program } {
  const configPath = ts.findConfigFile(
    dirname(sourcePath),
    ts.sys.fileExists,
    'tsconfig.godot.json',
  )
  if (configPath === undefined)
    throw new Error(`could not find tsconfig.godot.json for ${sourcePath}`)

  const config = ts.readConfigFile(configPath, ts.sys.readFile)
  if (config.error)
    throw new Error(formatDiagnostics([config.error]))

  const parsed = ts.parseJsonConfigFileContent(
    config.config,
    ts.sys,
    dirname(configPath),
    undefined,
    configPath,
  )
  if (parsed.errors.length > 0)
    throw new Error(formatDiagnostics(parsed.errors))

  return {
    configPath,
    program: ts.createProgram({
      rootNames: [...parsed.fileNames, wrapperPath],
      options: parsed.options,
    }),
  }
}

function formatDiagnostics(diagnostics: readonly ts.Diagnostic[]): string {
  return ts.formatDiagnostics(diagnostics, {
    getCanonicalFileName: fileName => fileName,
    getCurrentDirectory: ts.sys.getCurrentDirectory,
    getNewLine: () => ts.sys.newLine,
  })
}

function readTestLibraries(
  sourcePath: string,
): Array<{ from: string, to?: string }> {
  let directory = dirname(sourcePath)

  for (;;) {
    const configPath = resolve(directory, TSTOGD_CONFIG)
    if (existsSync(configPath)) {
      const config = JSON.parse(readFileSync(configPath, 'utf8')) as {
        lib?: boolean
        externalPackages?: Array<{ from: string, to?: string }>
      }
      if (!config.lib)
        throw new Error(`ViDot test package must set "lib": true: ${directory}`)

      return [
        { from: realpathSync(directory) },
        ...(config.externalPackages ?? []).map(item => ({
          ...item,
          from: isAbsolute(item.from) || !item.from.startsWith('.')
            ? item.from
            : resolve(directory, item.from),
        })),
      ]
    }

    const parent = dirname(directory)
    if (parent === directory)
      throw new Error(`could not find tstogd.json for ${sourcePath}`)
    directory = parent
  }
}

function transformTestModule(sourcePath: string, source: string): string {
  const sourceFile = ts.createSourceFile(
    sourcePath,
    source,
    ts.ScriptTarget.Latest,
    true,
  )
  const factory = ts.factory

  const lowerStatements = (statements: readonly ts.Statement[]): ts.Statement[] =>
    statements.flatMap((statement) => {
      const registration = readRegistration(statement)
      if (registration) {
        const callbackName = factory.createUniqueName('_vidotCallback')
        const callback = factory.updateArrowFunction(
          registration.callback,
          registration.callback.modifiers,
          registration.callback.typeParameters,
          registration.callback.parameters,
          registration.callback.type,
          registration.callback.equalsGreaterThanToken,
          factory.updateBlock(
            registration.body,
            lowerStatements(registration.body.statements),
          ),
        )
        const declaration = factory.createVariableStatement(
          undefined,
          factory.createVariableDeclarationList([
            factory.createVariableDeclaration(callbackName, undefined, undefined, callback),
          ], ts.NodeFlags.Const),
        )
        const call = factory.updateCallExpression(
          registration.call,
          registration.call.expression,
          registration.call.typeArguments,
          registration.call.arguments.map((argument, index) =>
            index === registration.callbackIndex ? callbackName : argument,
          ),
        )

        return [declaration, factory.updateExpressionStatement(registration.statement, call)]
      }

      return [statement]
    })

  const fileStatements: ts.Statement[] = []
  const collectionStatements: ts.Statement[] = []
  for (const statement of sourceFile.statements) {
    if (ts.isImportDeclaration(statement)
      && ts.isStringLiteral(statement.moduleSpecifier)
      && statement.moduleSpecifier.text === TEST_API_MODULE) {
      continue
    }
    if (ts.isImportDeclaration(statement))
      fileStatements.push(rewriteRelativeImport(sourcePath, statement, factory))
    else
      collectionStatements.push(...lowerStatements([statement]))
  }

  const apiBindings = TEST_API_NAMES.map(name => factory.createVariableStatement(
    undefined,
    factory.createVariableDeclarationList([
      factory.createVariableDeclaration(
        name,
        undefined,
        createCallableType(factory),
        factory.createPropertyAccessExpression(
          factory.createIdentifier('api'),
          name,
        ),
      ),
    ], ts.NodeFlags.Const),
  ))
  const moduleClass = factory.createClassDeclaration(
    [factory.createModifier(ts.SyntaxKind.ExportKeyword)],
    '_ViDotTestModule',
    undefined,
    [factory.createHeritageClause(ts.SyntaxKind.ExtendsKeyword, [
      factory.createExpressionWithTypeArguments(factory.createIdentifier('RefCounted'), undefined),
    ])],
    [factory.createMethodDeclaration(
      undefined,
      undefined,
      'vidot_collect',
      undefined,
      undefined,
      [factory.createParameterDeclaration(
        undefined,
        undefined,
        'api',
        undefined,
        factory.createKeywordTypeNode(ts.SyntaxKind.AnyKeyword),
      )],
      factory.createKeywordTypeNode(ts.SyntaxKind.VoidKeyword),
      factory.createBlock([...apiBindings, ...collectionStatements], true),
    )],
  )
  const wrapper = factory.updateSourceFile(sourceFile, [...fileStatements, moduleClass])

  return ts.createPrinter({ newLine: ts.NewLineKind.LineFeed }).printFile(wrapper)
}

function rewriteRelativeImport(
  sourcePath: string,
  statement: ts.ImportDeclaration,
  factory: ts.NodeFactory,
): ts.ImportDeclaration {
  if (!ts.isStringLiteral(statement.moduleSpecifier)
    || !statement.moduleSpecifier.text.startsWith('.')) {
    return statement
  }

  return factory.updateImportDeclaration(
    statement,
    statement.modifiers,
    statement.importClause,
    factory.createStringLiteral(resolve(dirname(sourcePath), statement.moduleSpecifier.text)),
    statement.attributes,
  )
}

function readRegistration(
  statement: ts.Statement,
): {
  call: ts.CallExpression
  callback: ts.ArrowFunction
  body: ts.Block
  callbackIndex: number
  statement: ts.ExpressionStatement
} | undefined {
  if (!ts.isExpressionStatement(statement)
    || !ts.isCallExpression(statement.expression)
    || !ts.isIdentifier(statement.expression.expression)) {
    return undefined
  }

  const name = statement.expression.expression.text
  if (!REGISTRATION_API_NAMES.includes(name))
    return undefined

  const callbackIndex = statement.expression.arguments.findIndex(argument =>
    ts.isArrowFunction(argument) && ts.isBlock(argument.body),
  )
  const callback = statement.expression.arguments[callbackIndex]
  if (callbackIndex < 0 || !ts.isArrowFunction(callback) || !ts.isBlock(callback.body))
    return undefined

  return {
    body: callback.body,
    call: statement.expression,
    callback,
    callbackIndex,
    statement,
  }
}

function createCallableType(factory: ts.NodeFactory): ts.FunctionTypeNode {
  return factory.createFunctionTypeNode(
    undefined,
    [factory.createParameterDeclaration(
      undefined,
      factory.createToken(ts.SyntaxKind.DotDotDotToken),
      'arguments_',
      undefined,
      factory.createArrayTypeNode(
        factory.createKeywordTypeNode(ts.SyntaxKind.AnyKeyword),
      ),
    )],
    factory.createKeywordTypeNode(ts.SyntaxKind.AnyKeyword),
  )
}
