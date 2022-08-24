extends Node2D

onready var monitorProgress = $MonitorProgress
onready var door = $Door
onready var cutscenePlayer = $CutscenePlayer

enum LevelState {
	LOADING
	PLAY
	COMPLETE
}

# other things rely on this being 10, leave for now
var DUST_PERCENTAGE = 10 # level is considered clear once this percentage of dust is remaining

var m_state = LevelState.LOADING
var m_totalDust : float
var m_progress : int = 0

func _ready():
	Events.connect("dust_amount_changed", self, "_on_dust_amount_changed")
	Events.connect("hit_time_limit", self, "_on_hit_time_limit")
	
	m_totalDust = Global.DustRemaining as float
	print("total dust:" + str(m_totalDust))
	SetState(LevelState.PLAY)

func _exit_tree():
	Events.disconnect("dust_amount_changed", self, "_on_dust_amount_changed")
	Events.disconnect("hit_time_limit", self, "_on_hit_time_limit")

func SetState(state):
	if m_state == state:
		return
	
	m_state = state
	var fString = "LevelState change: %s"
	var output
	match state:
		LevelState.LOADING:
			output = fString % "LOADING"
		LevelState.PLAY:
			output = fString % "PLAY"
		LevelState.COMPLETE:
			output = fString % "COMPLETE"
	print(output)
	
func _on_dust_amount_changed(amount):
	if m_state == LevelState.PLAY:
		var oldProgress = m_progress
		var percentangeRemaining = float(Global.DustRemaining / m_totalDust)
		m_progress = int(floor(10 - (percentangeRemaining * 10)))
		if oldProgress == m_progress:
			return
		
		print("level progress made: " + str(m_progress))
		monitorProgress.frame = m_progress
		if m_progress == 9:
			SetState(LevelState.COMPLETE)
			Events.emit_signal("level_complete")

func _on_hit_time_limit():
	if cutscenePlayer:
		cutscenePlayer.play("fired")

func OnCutsceneStart():
	door.OpenDoor()
	
func OnCutsceneEnd():
	Events.emit_signal("show_death_screen")
