extends Node

# pick dust pixel scale size here	1 = the 2x2 pixel
const DUST_SCALE = 1  	# 			2 = the 4x4 pixel
var DUST_SIZE = DUST_SCALE * 2

var DustRemaining : int = 0

func _ready():
	randomize()

func USecToMSec(usec : float):
	return usec / 1000.0
