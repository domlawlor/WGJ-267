extends Control

onready var menu : Control = $Menu
onready var levelList : VBoxContainer = $Menu/LevelList
onready var main_2d : Node2D = $Main2D
onready var bgm : AudioStreamPlayer = $BGM

onready var timeLimit : Timer = $TimeLimit
onready var animationPlayer : AnimationPlayer = $AnimationPlayer

var level_instance : Node2D

export var TotalTimeLimitSec : float = 30.0

func _ready():
	Events.connect("level_exited", self, "_on_level_exited")
	Events.connect("start_game", self, "_on_start_game")
	Events.connect("start_time_limit", self, "_on_start_time_limit")
	Events.connect("show_death_screen", self, "_on_show_death_screen")
	
	Global.TOTAL_TIME_LIMIT_SEC = TotalTimeLimitSec
	levelList.visible = false
	bgm.play()
	load_level("LevelTitle")

func _exit():
	Events.disconnect("level_exited", self, "_on_level_exited")
	Events.disconnect("start_time_limit", self, "_on_start_time_limit")
	Events.disconnect("show_death_screen", self, "_on_show_death_screen")

func unload_level():
	if (is_instance_valid(level_instance)):
		level_instance.queue_free()
		main_2d.remove_child(level_instance)
	level_instance = null

func load_level(level_name : String):
	unload_level()
	var level_path := "res://Levels/%s.tscn" % level_name
	var level_resource := load(level_path)
	if (level_resource):
		level_instance = level_resource.instance()
		main_2d.add_child(level_instance)
		levelList.visible = false

func _process(delta):
	if Input.is_action_just_pressed("toggle_menu"):
		levelList.visible = !levelList.visible
	
	if Input.is_action_just_pressed("debug_button_3"):
		animationPlayer.play("deathScreen")
	
	if Global.gameState == Global.GameState.BLOCKING_RESTART:
		if Input.is_action_just_pressed("button_ui_confirm"):
			StartGame()
	elif Global.gameState == Global.GameState.PLAYING:
		Global.TimeLimitTimeLeft = timeLimit.time_left

func _on_LoadLevelTitle_pressed():
	Global.gameState = Global.GameState.TITLE
	load_level("LevelTitle")

func _on_LoadLevel0_pressed():
	load_level("Level0")
	
func _on_LoadLevel1_pressed():
	load_level("Level1")

func _on_LoadLevel2_pressed():
	load_level("Level2")
	
func _on_DomsTestLevel_pressed():
	load_level("DomsTestLevel")

func _on_level_exited(num):
	match num:
		0:
			load_level("Level1")
		1:
			load_level("Level2")
		2:
			levelList.visible = true

func _on_start_game():
	StartGame()
	
func StartGame():
	animationPlayer.play("RESET")
	Global.DustRemaining = 0
	load_level("Level0")
	Events.emit_signal("start_time_limit")

func _on_start_time_limit():
	timeLimit.start(TotalTimeLimitSec)
	Global.gameState = Global.GameState.PLAYING
	
func _on_TimeLimit_timeout():
	Global.gameState = Global.GameState.DEAD
	Events.emit_signal("hit_time_limit")

func TriggerPlayerDeathAnimation():
	Events.emit_signal("player_death_animation")

func AllowRestartInput():
	Global.gameState = Global.GameState.BLOCKING_RESTART

func _on_show_death_screen():
	animationPlayer.play("deathScreen")
