export interface TestContext {
  tree: SceneTree
  instantiate: <T extends GodotObject>(path: string) => T | null
  waitUntil: (predicate: () => boolean, timeoutMs: int) => Promise<boolean>
}

export interface Expectation {
  toBe: (expected: unknown) => boolean
  toEqual: (expected: unknown) => boolean
}

type TestCallback = (context: TestContext) => unknown

export function describe(name: string, callback: () => unknown): void
export function test(name: string, callback: TestCallback): void
export function beforeAll(callback: TestCallback): void
export function beforeEach(callback: TestCallback): void
export function afterEach(callback: TestCallback): void
export function afterAll(callback: TestCallback): void
export function expect(actual: unknown): Expectation
