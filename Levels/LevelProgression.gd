extends Node2D

onready var monitorProgress = $MonitorProgress

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
	
	m_totalDust = Global.DustRemaining as float
	print("total dust:" + str(m_totalDust))
	SetState(LevelState.PLAY)

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
	
func _on_dust_amount_changed():
	if m_state == LevelState.PLAY:
		var oldProgress = m_progress
		var percentangeRemaining = float(Global.DustRemaining / m_totalDust)
		m_progress = floor(10 - (percentangeRemaining * 10))
		if oldProgress == m_progress:
			return
		
		print("level progress made: " + str(m_progress))
		monitorProgress.frame = m_progress
		if m_progress == 9:
			SetState(LevelState.COMPLETE)
			Events.emit_signal("level_complete")
