export class _ModMain extends Node {
  private controller: Node | null = null

  _ready() {
    const root = this.get_tree().root
    if (root.has_node('DataCollectorAI')) {
      push_error('The DataCollectorAI runtime already exists')

      return
    }

    const controller = gd.eval<Node>('preload("res://mods-unpacked/LemonNekoGH-DataCollectorAI/controller.gd").new()')
    controller.name = 'DataCollectorAI'
    root.call_deferred('add_child', controller)
    this.controller = controller
  }

  _exit_tree() {
    const controller = this.controller
    if (controller !== null && is_instance_valid(controller))
      controller.queue_free()
    this.controller = null
  }
}
