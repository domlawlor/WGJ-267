extends KinematicBody2D

onready var animatedSprite = $AnimatedSprite
onready var animationPlayer = $AnimationPlayer
onready var sweepTimer = $SweepTimer

enum PlayerState {
	GROUND
	AIR
	SWEEPING
}

var SWEEP_OFFSET : int = 20
var WALK_SPEED = 120
var GRAVITY = 1

var m_state = PlayerState.AIR
var m_velocity : Vector2 = Vector2.ZERO
var m_facingRight : bool = true

func _ready():
	animatedSprite.play("idle")

func _process(delta):
	if Input.is_action_pressed("moveLeft"):
		m_velocity.x = -WALK_SPEED
		m_facingRight = false
	elif Input.is_action_pressed("moveRight"):
		m_velocity.x = WALK_SPEED
		m_facingRight = true
	else:
		m_velocity.x = 0
	
	if m_state != PlayerState.SWEEPING:
		if m_velocity.x != 0:
			if animatedSprite.animation != "walk":
				animatedSprite.play("walk")
		elif animatedSprite.animation != "idle":
			animatedSprite.play("idle")
	
		animatedSprite.flip_h = !m_facingRight
	
	var col = move_and_collide(Vector2.DOWN, true, true, true)
	if col == null:
		m_velocity.y += GRAVITY
		m_state = PlayerState.AIR
		
	if Input.is_action_just_pressed("sweep") and sweepTimer.is_stopped():
		var posX : int
		if m_facingRight:
			posX = position.x + SWEEP_OFFSET
		else:
			posX = position.x - SWEEP_OFFSET
		m_state = PlayerState.SWEEPING
		sweepTimer.start()
		animatedSprite.play("sweep")
		Events.emit_signal("sweep", Vector2(posX, position.y), m_facingRight)
	
	col = move_and_collide(m_velocity * delta)
	if col != null:
		var ang = floor(rad2deg(col.get_angle()))
		if ang == 0:
			m_state = PlayerState.GROUND
			m_velocity.y = 0
		else:
			m_velocity.x = 0

func _on_SweepTimer_timeout():
	m_state = PlayerState.AIR
