extends Node2D

export var IsLeftOfLevel : bool = false

onready var collision = $Collision

func _ready():
	Events.connect("level_complete", self, "_on_level_complete")

func _on_level_complete():
	visible = false
	collision.queue_free()

func _on_LevelCompleteTriggerL_body_entered(body):
	if IsLeftOfLevel and body.is_in_group("player"):
		Events.emit_signal("level_exited")

func _on_LevelCompleteTriggerR_body_entered(body):
	if !IsLeftOfLevel and body.is_in_group("player"):
		Events.emit_signal("level_exited")
