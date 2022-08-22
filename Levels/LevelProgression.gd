extends Node2D

enum LevelState {
	LOADING
	PLAY
	COMPLETE
}

var DUST_PERCENTAGE = 10 # level is considered clear once this percentage of dust is remaining

var m_state = LevelState.LOADING
var m_targetDust : int

func _ready():
	Events.connect("level_exited", self, "_on_level_exited")
	
	m_targetDust = ceil(Global.DustRemaining / DUST_PERCENTAGE)
	print("target dust:" + str(m_targetDust))
	SetState(LevelState.PLAY)

func _process(delta):
	if m_state == LevelState.LOADING:
		return
	
	if m_state == LevelState.PLAY:
		if Global.DustRemaining <= m_targetDust:
			SetState(LevelState.COMPLETE)
			Events.emit_signal("level_complete")
	
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

func _on_level_exited():
	self.queue_free()
