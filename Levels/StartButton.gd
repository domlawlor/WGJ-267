extends Button

func _unhandled_input(event):
	if event.is_action_pressed("controller_ui_confirm"):
		Events.emit_signal("start_game")

func _on_StartButton_pressed():
	Events.emit_signal("start_game")
