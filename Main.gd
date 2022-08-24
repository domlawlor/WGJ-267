extends Control

onready var menu : Control = $Menu
onready var levelList : VBoxContainer = $Menu/LevelList
onready var main_2d : Node2D = $Main2D
onready var bgm : AudioStreamPlayer = $BGM

onready var timeLimit : Timer = $TimeLimit
onready var animationPlayer : AnimationPlayer = $AnimationPlayer

var level_instance : Node2D

export var TotalTimeLimitSec : float = 180.0

func _ready():
	Events.connect("level_exited", self, "_on_level_exited")
	Events.connect("start_game", self, "_on_start_game")
	Events.connect("start_time_limit", self, "_on_start_time_limit")
	Events.connect("show_death_screen", self, "_on_show_death_screen")
	Events.connect("sfx_sweep", self, "_on_sfx_sweep")
	Events.connect("sfx_janitorStart", self, "_on_sfx_janitorStart")
	Events.connect("sfx_grunt", self, "_on_sfx_grunt")
	
	Global.TOTAL_TIME_LIMIT_SEC = TotalTimeLimitSec
	levelList.visible = false
	bgm.play()
	load_level("LevelTitle")

func _exit():
	Events.disconnect("level_exited", self, "_on_level_exited")
	Events.disconnect("start_time_limit", self, "_on_start_time_limit")
	Events.disconnect("show_death_screen", self, "_on_show_death_screen")
	Events.disconnect("sfx_sweep", self, "_on_sfx_sweep")

func unload_level():
	if (is_instance_valid(level_instance)):
		level_instance.queue_free()
		main_2d.call_deferred("remove_child", level_instance)
	level_instance = null

func load_level(level_name : String):
	unload_level()
	Global.DustRemaining = 0
	var level_path := "res://Levels/%s.tscn" % level_name
	var level_resource := load(level_path)
	if (level_resource):
		level_instance = level_resource.instance()
		main_2d.call_deferred("add_child", level_instance)
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

# sfx
func _on_sfx_sweep():
	$SFX/Sweep.play()

func _on_sfx_janitorStart():
	var r = randi() % 3
	if r == 0:
		$SFX/JanitorStart01.play()
	elif r == 1:
		$SFX/JanitorStart02.play()
	else:
		$SFX/JanitorStart03.play()

func _on_sfx_grunt():
	var r = randi() % 4
	if r == 0:
		$SFX/JanitorGrunt01.play()
	elif r == 1:
		$SFX/JanitorGrunt02.play()
	elif r == 2:
		$SFX/JanitorGrunt03.play()
	else:
		$SFX/JanitorGrunt04.play()
