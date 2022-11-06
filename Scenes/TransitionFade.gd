extends Node2D

export var FadeLength : float = 1.0

onready var blackScreen = $BlackScreen
onready var timer = $Timer

#onready var bgm = get_node("../BGM")

var m_toBlack = true

func _ready():
	Events.connect("fade_to_black", self, "_on_fade_to_black")
	Events.connect("fade_to_transparent", self, "_on_fade_to_transparent")
	timer.wait_time = FadeLength
	#bgm.volume_db = -100
	
func _process(delta):
	if timer.is_stopped():
		if m_toBlack:
			blackScreen.modulate.a = 1
		else:
			blackScreen.modulate.a = 0
		return
	
	var timeLeftNorm = timer.time_left / timer.wait_time
	if m_toBlack:
		blackScreen.modulate.a = 1 - timeLeftNorm
		#bgm.volume_db = -100 * (1-timeLeftNorm)
	else:
		blackScreen.modulate.a = timeLeftNorm
		#bgm.volume_db = -100 * timeLeftNorm

func _on_fade_to_black():
	m_toBlack = true
	timer.start()
	
func _on_fade_to_transparent():
	m_toBlack = false
	timer.start()


func _on_Timer_timeout():
	if m_toBlack:
		Events.emit_signal("fade_to_black_complete")
	else:
		Events.emit_signal("fade_to_transparent_complete")
