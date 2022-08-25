extends Node2D

export var isFlying : bool = false
export var flyingDirection : Vector2 = Vector2.ZERO
export var flyingSpeed : float = 1.0

export var spawnArea : Rect2

func _ready():
	visible = false

func _on_SpawnTimer_timeout():
	var areaSize = spawnArea.size
	areaSize.x = max(areaSize.x, 1)
	areaSize.y = max(areaSize.y, 1)
	var randX : int = randi() % int(areaSize.x) - (int(areaSize.x) / 2)
	var randY : int = randi() % int(areaSize.y) - (int(areaSize.y) / 2)
	
	var midPoint = self.position
	var spawnPos = Vector2(midPoint.x + randX, midPoint.y + randY)
	
	flyingDirection = flyingDirection.normalized()
	
	# add some random variation to flyingDirection
	var angleVariance = 45
	var randomAngleChange = (randi() % angleVariance) - (angleVariance / 2)
	
	var dir = flyingDirection.rotated(deg2rad(randomAngleChange))
	
	var flyingVelocity = dir * flyingSpeed if isFlying else Vector2.ZERO
	Events.emit_signal("spawn_lava", spawnPos, isFlying, flyingVelocity)
