extends Node

func _ready():
	randomize()

var DustRemaining : int = 0



func USecToMSec(usec : float):
	return usec / 1000.0
