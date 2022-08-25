extends Control

onready var animationPlayer = $AnimationPlayer

onready var timeTakenText = $VBoxContainer/TimeTaken
onready var dustCleanedText = $VBoxContainer/DustCleaned
onready var numSweepsText = $VBoxContainer/NumSweeps

var resetInputEnabled = false

func _ready():
	Events.connect("show_win_screen", self, "_on_show_win_screen")
	Events.connect("sfx_death", self, "_on_sfx_death")
	animationPlayer.play("RESET")

func _exit_tree():
	Events.disconnect("show_win_screen", self, "_on_show_win_screen")
	Events.disconnect("sfx_death", self, "_on_sfx_death")

func _unhandled_input(event):
	if resetInputEnabled and event.is_action_pressed("sweep"):
		resetInputEnabled = false
		animationPlayer.play("RESET")
		Events.emit_signal("restart_game")
	
func SetRetryInputEnabled():
	resetInputEnabled = true
	
func SetRetryInputDisabled():
	resetInputEnabled = false

func _on_show_win_screen():
	var winTimeMSec = Global.WinTime * 1000.0
	timeTakenText.text = "Time - " + Global.MSecToTimeString(winTimeMSec, true)
	
	dustCleanedText.text = "Dust Removed - " + str(Global.DustCleaned)
	numSweepsText.text = "Number of Sweeps - " + str(Global.NumberOfSweeps)
	
	animationPlayer.play("win")

func _on_sfx_death():
	animationPlayer.queue("returnToMenu")
