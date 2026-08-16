import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { basename, resolve } from 'node:path'

import ts from 'typescript'
import { convertTsToGd } from 'typescript-to-gdscript'

export interface CompileTestFileOptions {
  sourcePath: string
  outputDirectory: string
}

export interface CompiledTestFile {
  scriptPath: string
}

const TEST_FILE_EXTENSION = /\.[cm]?tsx?$/
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
): Promise<CompiledTestFile> {
  const sourcePath = resolve(options.sourcePath)
  const outputDirectory = resolve(options.outputDirectory)
  const source = await readFile(sourcePath, 'utf8')
  const wrapper = transformTestModule(sourcePath, source)
  const stem = basename(sourcePath).replace(TEST_FILE_EXTENSION, '')
  const wrapperPath = resolve(outputDirectory, `${stem}.vidot.ts`)
  const scriptPath = resolve(outputDirectory, `${stem}.gd`)

  await mkdir(outputDirectory, { recursive: true })
  await writeFile(wrapperPath, wrapper)

  const result = convertTsToGd({
    filePath: wrapperPath,
    rootDir: outputDirectory,
    projectRoot: outputDirectory,
  })
  assertConversionSucceeded(sourcePath, result)

  await writeFile(scriptPath, result.code)
  return { scriptPath }
}

function assertConversionSucceeded(
  sourcePath: string,
  result: ReturnType<typeof convertTsToGd>,
): void {
  const errors = result.diagnostics.filter(diagnostic =>
    diagnostic.severity === 'error' || diagnostic.severity === 'type-error',
  )

  if (errors.length === 0)
    return

  const details = errors
    .map(diagnostic =>
      `${diagnostic.file}:${diagnostic.line}:${diagnostic.column}: ${diagnostic.message}`,
    )
    .join('\n')
  throw new Error(`tstogd could not compile ${sourcePath}:\n${details}`)
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
    if (ts.isImportDeclaration(statement))
      fileStatements.push(statement)
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
