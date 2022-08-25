extends Node

enum GameState {
	TITLE
	PLAYING
	DEAD
	WIN
	BLOCKING_RESTART
}
var gameState = GameState.TITLE

# pick dust pixel scale size here	1 = the 2x2 pixel
const DUST_SCALE = 1  	# 			2 = the 4x4 pixel
var DUST_SIZE = DUST_SCALE * 2

var DustRemaining : int = 0

var TOTAL_TIME_LIMIT_SEC : float = 30.0
var TimeLimitTimeLeft : float = 0.0
var WinTime : float = 0.0

var DustCleaned : int = 0
var NumberOfSweeps : int = 0
	

func _ready():
	randomize()

func USecToMSec(usec : float):
	return usec / 1000.0

func MSecToTimeString(msec : int, includeMsec):
	var workingTimeLeft = msec
	
	var msComp = workingTimeLeft % 1000
	workingTimeLeft = (workingTimeLeft - msComp) / 1000
	
	var secComp = workingTimeLeft % 60
	workingTimeLeft = (workingTimeLeft - secComp) / 60
	var minComp = workingTimeLeft % 60
	workingTimeLeft = (workingTimeLeft - minComp) / 60
	#var hourComp = workingTimeLeft
	#var hourComp = workingTimeLeft % 60
	
	var resultString
	if includeMsec:
		var formatString = "%s:%s.%s"
		resultString = formatString % [str(minComp).pad_zeros(2), str(secComp).pad_zeros(2), str(msComp).pad_zeros(3)]
	else:
		var formatString = "%s:%s"
		resultString = formatString % [str(minComp).pad_zeros(2), str(secComp).pad_zeros(2)]
	
#	if hourComp > 0:
#		var formatString = "%d:%s:%s.%d"
#		resultString = formatString % [hourComp, str(minComp).pad_zeros(2), str(secComp).pad_zeros(2), msComp]
#	else:
#		var formatString = "%s:%s.%d"
#		resultString = formatString % [str(minComp).pad_zeros(2), str(secComp).pad_zeros(2), msComp]
		
	return resultString

func SaveToFile(filePath, data):
	var file = File.new()
	file.open(filePath, File.WRITE)
	file.store_line(to_json(data))
	file.close()
