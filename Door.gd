extends Node2D

export var LevelNum : int = 0
export var IsLeftOfLevel : bool = false

onready var sprite = $Sprite
onready var collision = $Collision
onready var openSFX = $OpenSFX
onready var animationDelay = $AnimationDelay

func _ready():
	Events.connect("level_complete", self, "_on_level_complete")
	sprite.play("closed")
	
func _unhandled_input(event):
	if event.is_action_pressed("debug_button_5"):
		OpenDoor()

func _on_level_complete():
	OpenDoor()

func _on_LevelCompleteTriggerL_body_entered(body):
	if IsLeftOfLevel and body.is_in_group("player"):
		Events.emit_signal("level_exited", LevelNum)

func _on_LevelCompleteTriggerR_body_entered(body):
	if !IsLeftOfLevel and body.is_in_group("player"):
		Events.emit_signal("level_exited", LevelNum)

func OpenDoor():
	openSFX.play()
	animationDelay.start()
	collision.queue_free()

func _on_AnimationDelay_timeout():
	sprite.play("open")
