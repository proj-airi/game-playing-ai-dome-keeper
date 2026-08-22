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

export declare function describe(name: string, callback: () => unknown): void
export declare function test(name: string, callback: TestCallback): void
export declare function beforeAll(callback: TestCallback): void
export declare function beforeEach(callback: TestCallback): void
export declare function afterEach(callback: TestCallback): void
export declare function afterAll(callback: TestCallback): void
export declare function expect(actual: unknown): Expectation
