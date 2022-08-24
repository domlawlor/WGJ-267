extends Node2D

export var LevelNum : int = 0
export var IsLeftOfLevel : bool = false

onready var sprite = $Sprite
onready var scientist = $Scientist
onready var cutscenePlayer = $CutscenePlayer
onready var collision = $Collision
onready var openSFX = $OpenSFX
onready var animationDelay = $AnimationDelay

const SCIENTIST_R = 87
const SCIENTIST_L = -60

var m_open = false

func _ready():
	Events.connect("level_complete", self, "_on_level_complete")
	Events.connect("hit_time_limit", self, "_on_hit_time_limit")
	sprite.play("closed")
	if IsLeftOfLevel:
		scientist.position.x = SCIENTIST_L
	else:
		scientist.position.x = SCIENTIST_R

func _exit_tree():
	Events.disconnect("level_complete", self, "_on_level_complete")
	Events.disconnect("hit_time_limit", self, "_on_hit_time_limit")

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
	if m_open:
		return
	m_open = true
	openSFX.play()
	animationDelay.start()
	collision.queue_free()

func _on_AnimationDelay_timeout():
	sprite.play("open")
	
func _on_hit_time_limit():
	if IsLeftOfLevel:
		cutscenePlayer.play("fired_l")
	else:
		cutscenePlayer.play("fired_r")

func OnCutsceneStart():
	OpenDoor()
	
func OnCutsceneEnd():
	Events.emit_signal("show_death_screen")
