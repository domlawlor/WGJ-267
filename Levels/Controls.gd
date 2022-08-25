extends Node2D

func _ready():
	Events.connect("sweep", self, "_on_sweep")

func _on_sweep(pos, facingRight):
	$AnimationPlayer.seek(0)
	$AnimationPlayer.play("buttonPress")
