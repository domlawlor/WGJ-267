extends Node2D

func _on_Area2D_body_entered(body):
	if body.is_in_group("player"):
		Events.emit_signal("ladder_climbing_activate")


func _on_Area2D_body_exited(body):
	if body.is_in_group("player"):
		Events.emit_signal("ladder_climbing_deactivate")
