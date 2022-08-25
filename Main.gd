extends Control

onready var menu : Control = $Menu
onready var levelList : VBoxContainer = $Menu/LevelList
onready var main_2d : Node2D = $Main2D
onready var bgm : AudioStreamPlayer = $BGM

onready var timeLimit : Timer = $TimeLimit
onready var animationPlayer : AnimationPlayer = $AnimationPlayer

var level_instance : Node2D

export var TotalTimeLimitSec : float = 120.0

func _ready():
	Events.connect("level_exited", self, "_on_level_exited")
	Events.connect("start_game", self, "_on_start_game")
	Events.connect("win_game", self, "_on_win_game")
	Events.connect("restart_game", self, "_on_restart_game")
	Events.connect("start_time_limit", self, "_on_start_time_limit")
	Events.connect("show_death_screen", self, "_on_show_death_screen")
	Events.connect("sfx_sweep", self, "_on_sfx_sweep")
	Events.connect("sfx_janitorStart", self, "_on_sfx_janitorStart")
	Events.connect("sfx_grunt", self, "_on_sfx_grunt")
	Events.connect("sfx_death", self, "_on_sfx_death")
	
	Global.TOTAL_TIME_LIMIT_SEC = TotalTimeLimitSec
	levelList.visible = false
	
	load_level("LevelTitle", false)
	yield(get_tree().create_timer(1), "timeout")
	bgm.play()
	Events.emit_signal("fade_to_transparent")
	yield(Events, "fade_to_transparent_complete")

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

func load_level(level_name : String, transitionFade : bool):
	if transitionFade:
		Events.emit_signal("fade_to_black")
	
	unload_level()
	
	if transitionFade:
		yield(Events, "fade_to_black_complete")
	Global.DustRemaining = 0
	var level_path := "res://Levels/%s.tscn" % level_name
	var level_resource := load(level_path)
	if (level_resource):
		level_instance = level_resource.instance()
		main_2d.call_deferred("add_child", level_instance)
		levelList.visible = false
	
	if level_name == "LevelTitle":
		$Menu/StartButton.MakeActive()
	else:
		$Menu/StartButton.MakeInactive()
	
	if transitionFade:
		Events.emit_signal("fade_to_transparent")
		yield(Events, "fade_to_transparent_complete")

func _process(delta):
	if Input.is_action_just_pressed("toggle_menu"):
		levelList.visible = !levelList.visible
	
#	if Input.is_action_just_pressed("debug_button_3"):
#		animationPlayer.play("deathScreen")
	
	if Global.gameState == Global.GameState.BLOCKING_RESTART:
		if Input.is_action_just_pressed("button_ui_confirm"):
			StartGame()
	elif Global.gameState == Global.GameState.PLAYING:
		Global.TimeLimitTimeLeft = timeLimit.time_left

func _on_LoadLevelTitle_pressed():
	Global.gameState = Global.GameState.TITLE
	load_level("LevelTitle", true)

func _on_LoadLevel0_pressed():
	load_level("Level0", true)
	
func _on_LoadLevel1_pressed():
	load_level("Level1", true)

func _on_LoadLevel2_pressed():
	load_level("Level2", true)

func _on_LoadLevel3_pressed():
	load_level("Level3", true)
	
func _on_DomsTestLevel_pressed():
	load_level("DomsTestLevel", true)

func _on_level_exited(num):
	match num:
		0:
			load_level("Level1", true)
		1:
			load_level("Level2", true)
		2:
			load_level("Level3", true)

func _on_restart_game():
	timeLimit.stop()
	load_level("LevelTitle", true)

func _on_start_game():
	StartGame()
	
func StartGame():
	Global.WinTime = 0.0
	Global.DustCleaned = 0
	Global.NumberOfSweeps = 0
	animationPlayer.play("RESET")
	load_level("Level0", true)
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

func _on_win_game():
	Global.WinTime = timeLimit.wait_time - timeLimit.time_left

func _on_show_death_screen():
	animationPlayer.play("deathScreen")
	timeLimit.stop()

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

func _on_sfx_death():
	var r = randi() % 2
	if r == 0:
		$SFX/JanitorDeath01.play()
	elif r == 1:
		$SFX/JanitorDeath02.play()
