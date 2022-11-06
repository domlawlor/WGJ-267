extends KinematicBody2D

onready var animatedSprite = $AnimatedSprite
onready var sweepTimer = $SweepTimer
onready var respawnTimer = $RespawnTimer
onready var startSoundTimer = $StartSoundTimer
onready var voiceCooldown = $VoiceCooldown

onready var dustSim = get_node("../DustSim")

enum PlayerState {
	GROUND
	AIR
	LADDER
	SWEEPING
	DEAD
	FROZEN
}

const SWEEP_OFFSET : float = 20.0
const WALK_SPEED = 120
const LADDER_SPEED = 100
const GRAVITY = 18
const SINK_SPEED = 10

const GRUNT_DELAY_MIN : float = 2.0
const GRUNT_DELAY_MAX : float = 5.0

var m_spawnPos : Vector2
var m_state
var m_velocity : Vector2
var m_ladderActive : bool
var m_facingRight : bool
var m_voiceActive : bool

func _ready():
	Events.connect("ladder_climbing_activate", self, "_on_ladder_climbing_activate")
	Events.connect("ladder_climbing_deactivate", self, "_on_ladder_climbing_deactivate")
	#Events.connect("debug_set_player_pos", self, "_on_debug_set_player_pos")
	Events.connect("hit_time_limit", self, "_on_hit_time_limit")
	Events.connect("win_game", self, "_on_win_game")
	Events.connect("unfreeze_player", self, "_on_unfreeze_player")
	Events.connect("player_death_animation", self, "_on_player_death_animation")
	
	m_spawnPos = position
	ResetPlayer()

func _exit_tree():
	Events.disconnect("ladder_climbing_activate", self, "_on_ladder_climbing_activate")
	Events.disconnect("ladder_climbing_deactivate", self, "_on_ladder_climbing_deactivate")
	#Events.disconnect("debug_set_player_pos", self, "_on_debug_set_player_pos")
	Events.disconnect("hit_time_limit", self, "_on_hit_time_limit")
	Events.disconnect("win_game", self, "_on_win_game")
	Events.disconnect("unfreeze_player", self, "_on_unfreeze_player")
	Events.disconnect("player_death_animation", self, "_on_player_death_animation")

func ResetPlayer():
	position = m_spawnPos
	animatedSprite.play("idle")
	m_state = PlayerState.AIR
	m_velocity = Vector2.ZERO
	m_ladderActive = false
	m_facingRight = true
	m_voiceActive = false
	voiceCooldown.start(4.0)
	startSoundTimer.start()

func _process(delta):
#	if Input.is_action_just_pressed("debug_button_1"):
#		var mousePos = get_viewport().get_mouse_position()
#		Events.emit_signal("debug_set_player_pos", mousePos / 2)
	
	if m_state == PlayerState.FROZEN:
		return
	
	if m_state == PlayerState.DEAD:
		position.y += SINK_SPEED * delta
		return
	
	if dustSim.IsPlayerInLava(self):
		SetPlayerState(PlayerState.DEAD)
		animatedSprite.play("dead")
		Events.emit_signal("sfx_death")
		if Global.gameState != Global.GameState.WIN:
			respawnTimer.start()
		return
	
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
		else:
			if m_state != PlayerState.SWEEPING:
				SetPlayerState(PlayerState.GROUND)
	
	var canSweep = m_state == PlayerState.GROUND and sweepTimer.is_stopped()
	if canSweep and Input.is_action_pressed("sweep"):
		var posX : int
		if m_facingRight:
			posX = int(position.x + SWEEP_OFFSET)
		else:
			posX = int(position.x - SWEEP_OFFSET)
		SetPlayerState(PlayerState.SWEEPING)
		sweepTimer.start()
		animatedSprite.play("sweep")
		Events.emit_signal("sfx_sweep")
		Events.emit_signal("sweep", Vector2(posX, position.y), m_facingRight)
		Global.NumberOfSweeps += 1
		if voiceCooldown.is_stopped():
			Events.emit_signal("sfx_grunt")
			voiceCooldown.start(rand_range(GRUNT_DELAY_MIN, GRUNT_DELAY_MAX))
	
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
		var col : KinematicCollision2D = move_and_collide(frameVel, true, true, true)
		if col != null:
			if frameVel.y > 0:
				var yCol : KinematicCollision2D = move_and_collide(Vector2(0, frameVel.y), true, true, true)
				if yCol != null:
					m_velocity.y = 0
			var xCol : KinematicCollision2D = move_and_collide(Vector2(frameVel.x, 0), true, true, true)
			if xCol != null:
				m_velocity.x = 0
			move_and_collide(m_velocity * delta)
			var ang = floor(rad2deg(col.get_angle()))
			if ang == 0:
				SetPlayerState(PlayerState.GROUND)
				m_velocity.y = 0
		else:
			position.x += frameVel.x
			position.y += frameVel.y
	else:
		var col = move_and_collide(frameVel, true, true, true)
		if col != null:
			var ang = floor(rad2deg(col.get_angle()))
			if ang != 0:
				m_velocity.x = 0
				frameVel = m_velocity * delta
		col = move_and_collide(frameVel)
		if col != null:
			var ang = floor(rad2deg(col.get_angle()))
			if ang == 0:
				SetPlayerState(PlayerState.GROUND)
				m_velocity.y = 0

func SetPlayerState(state):
	if m_state == state:
		return
	
	if state == PlayerState.LADDER and m_state != PlayerState.LADDER:
		print("player_using_ladder - true")
		Events.emit_signal("player_using_ladder", true)
	elif state != PlayerState.LADDER and m_state == PlayerState.LADDER:
		print("player_using_ladder - false")
		Events.emit_signal("player_using_ladder", false)
	
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
		PlayerState.DEAD:
			output = fString % "DEAD"
	#print(output)

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
	if m_state == PlayerState.SWEEPING:
		SetPlayerState(PlayerState.AIR)

func _on_hit_time_limit():
	m_state = PlayerState.FROZEN
	animatedSprite.play("idle")

func _on_win_game():
	m_facingRight = true
	animatedSprite.flip_h = !m_facingRight
	m_state = PlayerState.FROZEN
	animatedSprite.play("idle")

func _on_unfreeze_player():
	if m_ladderActive:
		m_state = PlayerState.LADDER
	else:
		m_state = PlayerState.AIR

#func _on_debug_set_player_pos(mousePos):
#	position = mousePos
#	m_state = PlayerState.GROUND
#	m_ladderActive = false

func _on_RespawnTimer_timeout():
	ResetPlayer()

func _on_player_death_animation():
	animatedSprite.play("dead")

func _on_StartSoundTimer_timeout():
	Events.emit_signal("sfx_janitorStart")

func _on_VoiceCooldown_timeout():
	m_voiceActive = true
