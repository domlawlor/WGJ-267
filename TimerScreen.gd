extends Node2D

#onready var labelA = $LabelA
onready var labelB = $LabelB

func _ready():
	Events.connect("hit_time_limit", self, "_on_hit_time_limit")

func _exit_tree():
	Events.disconnect("hit_time_limit", self, "_on_hit_time_limit")
	
func _process(delta):
	var timeLeftMsec = Global.TimeLimitTimeLeft * 1000
	if timeLeftMsec > 0:
		var timeString = Global.MSecToTimeString(timeLeftMsec)
		#labelA.text = timeString
		labelB.text = timeString

func _on_hit_time_limit():
	labelB.text = "! ! !"
