import { _DataCollectorAI } from './controller.ts'

export class _ModMain extends Node {
  _ready() {
    const root = this.get_tree().root
    if (root.has_node('DataCollectorAI')) {
      push_error('The DataCollectorAI runtime already exists')

      return
    }

    const controller = new _DataCollectorAI()
    controller.name = 'DataCollectorAI'
    root.call_deferred('add_child', controller)
  }
}
