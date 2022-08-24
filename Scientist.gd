extends Node2D

onready var scientistA : AnimatedSprite = $ScientistA
onready var scientistB : AnimatedSprite = $ScientistB
onready var firedText : Label = $FiredText

var scientistUsed : AnimatedSprite

func _ready():
	scientistUsed = scientistA if randi() % 2 == 0 else scientistB
	scientistUsed.visible = true

func FaceLeft():
	scientistUsed.flip_h = true

func FaceRight():
	scientistUsed.flip_h = false
	
func FlipH():
	scientistUsed.flip_h = !scientistUsed.flip_h

func SetAnimation(animation):
	scientistUsed.animation = animation
	
func ToggleText():
	firedText.visible = !firedText.visible
