export interface ViDotOptions {
  projectPath: string
  godotPath?: string
  launch?: ViDotLaunch
}

export interface ResolvedViDotOptions {
  projectPath: string
  godotPath: string
  runnerPath: string
  launch: ViDotLaunch
}

export interface ViDotLaunchContext {
  method: 'run' | 'collect'
}

export interface ViDotLaunchOptions {
  args: string[]
  env?: Record<string, string>
  before?: () => Promise<void>
  after?: () => Promise<void>
}

export type ViDotLaunch = (context: ViDotLaunchContext) => ViDotLaunchOptions

export interface ViDotSuiteNode {
  type: 'suite'
  id: string
  name: string
  children: ViDotTaskNode[]
}

export interface ViDotTestNode {
  type: 'test'
  id: string
  name: string
}

export type ViDotTaskNode = ViDotSuiteNode | ViDotTestNode

export interface ViDotError {
  name?: string
  message: string
}

export type ViDotEvent
  = | {
    type: 'file_collected'
    file: string
    tree: ViDotSuiteNode
  }
  | {
    type: 'test_start'
    file: string
    id: string
  }
  | {
    type: 'test_finish'
    file: string
    id: string
    state: 'pass' | 'fail'
    duration?: number
    errors?: ViDotError[]
  }
  | {
    type: 'file_finish'
    file: string
    duration?: number
    errors?: ViDotError[]
  }
  | {
    type: 'run_finish'
  }
