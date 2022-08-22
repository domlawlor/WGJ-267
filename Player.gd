extends KinematicBody2D

onready var animatedSprite = $AnimatedSprite
onready var sweepTimer = $SweepTimer
onready var sweepSFX = $SweepSFX

enum PlayerState {
	GROUND
	AIR
	LADDER
	SWEEPING
}

var SWEEP_OFFSET : int = 20
var WALK_SPEED = 120
var LADDER_SPEED = 100
var GRAVITY = 18

var m_state = PlayerState.AIR
var m_velocity : Vector2 = Vector2.ZERO
var m_ladderActive : bool = false
var m_facingRight : bool = true

func _ready():
	Events.connect("ladder_climbing_activate", self, "_on_ladder_climbing_activate")
	Events.connect("ladder_climbing_deactivate", self, "_on_ladder_climbing_deactivate")
	Events.connect("debug_set_player_pos", self, "_on_debug_set_player_pos")
	animatedSprite.play("idle")


func _process(delta):
	if Input.is_action_just_pressed("debug_button_1"):
		var mousePos = get_viewport().get_mouse_position()
		Events.emit_signal("debug_set_player_pos", mousePos / 2)
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
	
	if m_state != PlayerState.LADDER:
		var col = move_and_collide(Vector2.DOWN, true, true, true)
		if col == null:
			m_velocity.y += GRAVITY
			SetPlayerState(PlayerState.AIR)
		
	if Input.is_action_just_pressed("sweep") and sweepTimer.is_stopped():
		var posX : int
		if m_facingRight:
			posX = position.x + SWEEP_OFFSET
		else:
			posX = position.x - SWEEP_OFFSET
		SetPlayerState(PlayerState.SWEEPING)
		sweepTimer.start()
		animatedSprite.play("sweep")
		sweepSFX.play()
		Events.emit_signal("sweep", Vector2(posX, position.y), m_facingRight)
	
	var canClimbLadder = m_ladderActive and m_state != PlayerState.SWEEPING
	if canClimbLadder:
		if Input.is_action_pressed("ladderDown"):
			m_velocity.y = LADDER_SPEED
			SetPlayerState(PlayerState.LADDER)
		elif Input.is_action_pressed("ladderUp"):
			m_velocity.y = -LADDER_SPEED
			SetPlayerState(PlayerState.LADDER)
		elif m_state == PlayerState.LADDER:
			m_velocity.y = 0
	
	var frameVel = m_velocity * delta
	if m_state == PlayerState.LADDER:
		print("frameVel: " + str(frameVel))
		var col : KinematicCollision2D = move_and_collide(frameVel, true, true, true)
		if col != null and !col.collider.is_in_group("ladder_top"):
			move_and_collide(frameVel)   # the bug is because we end up in here even though we appear to be only colliding with a ladder_top block
			SetPlayerState(PlayerState.GROUND)
		else:
			position.y += frameVel.y
	else:
		var col = move_and_collide(frameVel)
		if col != null:
			var ang = floor(rad2deg(col.get_angle()))
			if ang == 0:
				SetPlayerState(PlayerState.GROUND)
				m_velocity.y = 0
			else:
				m_velocity.x = 0

func SetPlayerState(state):
	if m_state == state:
		return
	
	m_state = state
	var fString = "PlayerState change: %s"
	var output
	match state:
		PlayerState.AIR:
			output = fString % "AIR"
		PlayerState.GROUND:
			output = fString % "GROUND"
		PlayerState.LADDER:
			output = fString % "LADDER"
		PlayerState.SWEEPING:
			output = fString % "SWEEPING"
	print(output)

func _on_ladder_climbing_activate():
	print("ladder active")
	m_ladderActive = true
	
func _on_ladder_climbing_deactivate():
	print("ladder inactive")
	m_ladderActive = false
	if m_state == PlayerState.LADDER:
		SetPlayerState(PlayerState.AIR)
		m_velocity.y = 0

func _on_SweepTimer_timeout():
	SetPlayerState(PlayerState.AIR)

func _on_debug_set_player_pos(mousePos):
	print("in _on_debug_set_player_pos")
	position = mousePos
	m_state = PlayerState.GROUND
	m_ladderActive = false
