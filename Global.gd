extends Node

func _ready():
	randomize()

func USecToMSec(usec : float):
	return usec / 1000.0
