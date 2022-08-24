extends Button

func _on_StartButton_pressed():
	Events.emit_signal("start_game")
