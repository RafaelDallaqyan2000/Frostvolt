extends PanelContainer
# A reward in the build panel. A press starts the drag; the card keeps mouse focus until release,
# so motion and release outside it still arrive here. Touch reaches it through mouse emulation.
var game
var index := 0
var item: Dictionary

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  accept_event()
  if event.pressed: game.begin_drag(index, event.global_position)
  else: game.end_drag(event.global_position)
 elif event is InputEventMouseMotion and game.drag != null and game.drag.index == index:
  accept_event()
  game.update_drag(event.global_position)
