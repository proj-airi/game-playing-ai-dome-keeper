export interface ViDotOptions {
  projectPath: string
  godotPath?: string
}

export interface ResolvedViDotOptions {
  projectPath: string
  godotPath: string
  runnerPath: string
}

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
