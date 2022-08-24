extends Node2D

onready var staticBody2D = $StaticBody2D

func _ready():
	Events.connect("player_using_ladder", self, "_on_player_using_ladder")
	
func _exit_tree():
	Events.disconnect("player_using_ladder", self, "_on_player_using_ladder")

func _on_Area2D_body_entered(body):
	if body.is_in_group("player"):
		Events.emit_signal("ladder_climbing_activate")


func _on_Area2D_body_exited(body):
	if body.is_in_group("player"):
		Events.emit_signal("ladder_climbing_deactivate")

func _on_player_using_ladder(usingLadder):
	staticBody2D.set_collision_layer_bit(0, !usingLadder)
	staticBody2D.set_collision_mask_bit(0, !usingLadder)
