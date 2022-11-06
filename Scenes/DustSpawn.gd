extends Node2D

export var DustAmount : int = 10 # will make a square of dust i.e 10 = 100 dust

func _ready():
	visible = false
	var dustAmount = DustAmount
	if Global.DUST_SCALE == 2:
		dustAmount = int(DustAmount * 0.7)
	Events.emit_signal("spawn_dust", position, dustAmount)
