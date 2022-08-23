extends Node2D

onready var labelA = $LabelA
onready var labelB = $LabelB

func _process(delta):
	var timeLeftMsec = Global.TimeLimitTimeLeft * 1000
	var timeString = Global.MSecToTimeString(timeLeftMsec)
	labelA.text = timeString
	labelB.text = timeString
