extends Sprite

onready var animationPlayer = $AnimationPlayer

func _ready():
	visible = true
	animationPlayer.play("OverlayHazeMovement")
