extends Node2D

export var DirectionLeft : bool = false

func _ready():
	visible = false

func _on_SpawnTimer_timeout():
	Events.emit_signal("spawn_lava", self.position, DirectionLeft)
