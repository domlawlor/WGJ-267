extends Node2D

export(Color) var dustColourA
export(Color) var dustColourB
export(Color) var dustColourC
export(Color) var dustColourD

enum PixelType {
	EMPTY
	DUST
	FLYING_DUST
	COLLISION
	KILL
}

onready var sprite_2x : Sprite = $Sprite_2x
onready var sprite_4x : Sprite = $Sprite_4x
var sprite : Sprite # set in _ready

const FIRE_DUST_TEST = false

var enabledDebugDrawCollision = false
var enabledDebugDrawRegions = false
var enabledDebugDrawDirtyRects = false

const DIRTY_RECT_BOUNDARY = 1

var worldSizeX : int = 640
var worldSizeY : int = 480

var pixelSizeScale : int
var pixelWorldSizeX : int
var pixelWorldSizeY : int
var pixelTypes = []

# just using this as a test for adding more state. Will incorporate type if it works
var pixelState = [] # pixel array
var pixelVelocity = []

var REGION_SIZE = 16
var regionWorldSizeX : int
var regionWorldSizeY : int

var activeRegionsBufferNum = 0
var nextRegionsBufferNum = 1
var checkRegionsBuffers = [[], []]

var regionHalfSizeX : int
var regionHalfSizeY : int

var totalRegionCount : int

var FORCE_COUNT = 20
var forceCount = 0
var forcePos : Vector2 = Vector2.ZERO
var forceRight = true

func _ready():
	Events.connect("sweep", self, "_on_sweep")
	Events.connect("spawn_dust", self, "_on_spawn_dust")
	
	if Global.DUST_SCALE == 1:
		sprite = sprite_2x
	elif Global.DUST_SCALE == 2:
		sprite = sprite_4x
	else:
		assert(false) # bad DUST_SCALE value!
	
	sprite.visible = true
	pixelSizeScale = Global.DUST_SIZE
	
	pixelWorldSizeX = worldSizeX / pixelSizeScale
	pixelWorldSizeY = worldSizeY / pixelSizeScale
	
	assert(REGION_SIZE % 2 == 0) # pls, just don't make uneven
	
	#regionWorldSizeX = pixelWorldSizeX / REGION_SIZE
	#regionWorldSizeY = pixelWorldSizeY / REGION_SIZE
	regionWorldSizeX = ceil(pixelWorldSizeX as float / REGION_SIZE as float)
	regionWorldSizeY = ceil(pixelWorldSizeY as float / REGION_SIZE as float)
	
	# just caching for the sake of any sort of speed increase
	regionHalfSizeX = REGION_SIZE / 2
	regionHalfSizeY = REGION_SIZE / 2
	
	totalRegionCount = regionWorldSizeX * regionWorldSizeY
	
	print("TextureSize-", sprite.get_texture().get_size())
	print("Image-", sprite.get_texture().get_data().get_size())
	ClearWorld()
	SetLevelCollisions()

func _exit_tree():
	Events.disconnect("sweep", self, "_on_sweep")
	Events.disconnect("spawn_dust", self, "_on_spawn_dust")

func GetPixelState(pos):
	return pixelState[(pos.y * pixelWorldSizeX) + pos.x]

func SetPixelState(pos, state):
	pixelState[(pos.y * pixelWorldSizeX) + pos.x] = state


func GetPixel(pos):
	return pixelTypes[(pos.y * pixelWorldSizeX) + pos.x]

func SetPixel(pos, type):
	pixelTypes[(pos.y * pixelWorldSizeX) + pos.x] = type
	ActivateRegion(pos)

func ActivateRegion(pos):
	var regX = floor(pos.x / REGION_SIZE)
	var regY = floor(pos.y / REGION_SIZE)
	var regIndex : int = regY * regionWorldSizeX + regX
	
	var regionBuffer = checkRegionsBuffers[nextRegionsBufferNum]
	var dirtyRect = regionBuffer[regIndex]
	
	if !dirtyRect:
		# default values are intended. Makes the min and max functions work
		regionBuffer[regIndex] = { 
			minX = pixelWorldSizeX, 
			minY = pixelWorldSizeX,
			maxX = 0,
			maxY = 0
		}
		dirtyRect = regionBuffer[regIndex]
	
	dirtyRect.minX = min(dirtyRect.minX, pos.x)
	dirtyRect.minY = min(dirtyRect.minY, pos.y)
	dirtyRect.maxX = max(dirtyRect.maxX, pos.x)
	dirtyRect.maxY = max(dirtyRect.maxY, pos.y)

func ClearWorld():
	var pixelCount = pixelWorldSizeX * pixelWorldSizeY
	pixelTypes.resize(pixelCount)
	pixelTypes.fill(PixelType.EMPTY)
	
	pixelState.resize(pixelCount)
	pixelState.fill(false)
	
	pixelVelocity.resize(pixelCount)
	pixelVelocity.fill(Vector2.ZERO)
	
	var regionCount = regionWorldSizeX * regionWorldSizeY
	for regionsBuffer in checkRegionsBuffers:
		regionsBuffer.resize(regionCount)
		regionsBuffer.fill(null)
	
	var image = sprite.get_texture().get_data()
	image.lock()
	image.fill(Color.transparent)
	image.unlock()
	sprite.get_texture().set_data(image)

func SetLevelCollisions():
	var space_rid = get_world_2d().space
	var space_state = Physics2DServer.space_get_direct_state(space_rid)
	
	for i in range(0, pixelTypes.size()):
		var testPos = Vector2()
		testPos.x = ((i % pixelWorldSizeX) * pixelSizeScale) + 1
		testPos.y = (floor(i / pixelWorldSizeX) * pixelSizeScale) + 1
		
		var collisions = space_state.intersect_point(testPos)
		for col in collisions:
			var collider = col.collider
			if collider.is_in_group("player"):
				continue
			
			if collider.is_in_group("dust_kill"):
				pixelTypes[i] = PixelType.KILL
			else:
				pixelTypes[i] = PixelType.COLLISION

func _on_spawn_dust(pos, amount):
	var simPos = GetSimPos(pos)
	var positions = []
	var xStart = simPos.x - floor(amount / 2)
	var yStart = simPos.y - amount
	for x in range(0, amount):
		for y in range(0, amount):
			positions.push_back(Vector2(xStart + x, yStart + y))
	CreateDust(positions)

func GetDustColor():
	var color
	var randIdx = randi() % 4
	match(randIdx):
		0:
			color = dustColourA
		1:
			color = dustColourB
		2:
			color = dustColourC
		3:
			color = dustColourD
	return color

func FireDust(pos, canMakeDust):
	var xRand = randf()
	var velX = -xRand if randi() % 2 else xRand
	var velY = -randf()
	var vel = Vector2(velX, velY)
	vel = vel.normalized()
	FireDustInDir(pos, vel, canMakeDust)

func FireDustInDir(pos, vel, canMakeDust):
	# pick a random direction from simPos and fire it with a fixed velocity
	var image = sprite.get_texture().get_data()
	image.lock()
	
	var pixelType = GetPixel(pos)
	if !canMakeDust and pixelType != PixelType.DUST:
		return
	if canMakeDust and pixelType != PixelType.EMPTY:
		return
	
	#randomise launch a bit
	vel = vel.normalized()
	
	SetPixel(pos, PixelType.FLYING_DUST)
	pixelVelocity[(pos.y * pixelWorldSizeX) + pos.x] = vel
	
	if pixelType == PixelType.EMPTY:
		var color = GetDustColor()
		image.set_pixelv(pos, color)
		ActivateRegion(pos)
		Global.DustRemaining += 1
		Events.emit_signal("dust_amount_changed", 1)
	
	image.unlock()
	sprite.get_texture().set_data(image)
	
func CreateDust(positions):
	var amountCreated : int = 0
	var image = sprite.get_texture().get_data()
	image.lock()
	
	for pos in positions:
		if !IsPositionEmpty(pos):
			continue
		
		#print("CreateDust xPos:", pos.x, ", yPos:", pos.y)
		SetPixel(pos, PixelType.DUST)
		
		var color = GetDustColor()
		image.set_pixelv(pos, color)
		
		amountCreated += 1
	
	image.unlock()
	sprite.get_texture().set_data(image)
	Global.DustRemaining += amountCreated
	Events.emit_signal("dust_amount_changed", amountCreated)
	#print("Dust remaining: " + str(Global.DustRemaining))

func CreateBulkDust(pos):
	var positions = [pos]
	positions.push_back(Vector2(pos.x - (randi() % 10), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x + (randi() % 10), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x + (randi() % 12), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x - (randi() % 12), pos.y - (randi() % 14)))
	CreateDust(positions)

func IsInBounds(pos):
	var inXBounds = pos.x < pixelWorldSizeX and pos.x >= 0
	var inYBounds = pos.y < pixelWorldSizeY and pos.y >= 0
	return inXBounds and inYBounds

func MovePixel(srcPos, destPos, image):
	var destPosType = GetPixel(destPos)
	assert(destPosType == PixelType.EMPTY or destPosType == PixelType.KILL)
	if destPosType == PixelType.EMPTY:
		SetPixel(destPos, GetPixel(srcPos)) # move dust
		image.set_pixelv(destPos, image.get_pixelv(srcPos))
	else:
		Global.DustRemaining -= 1 # destroy dust
		Events.emit_signal("dust_amount_changed", -1)
		#print("kill! " + str(Global.DustRemaining))
	SetPixel(srcPos, PixelType.EMPTY)
	image.set_pixelv(srcPos, Color.transparent)

func UpdateFlyingDustPixel(pos, delta, image):
	var movePos = null
	
	var vel = pixelVelocity[(pos.y * pixelWorldSizeX) + pos.x]
	
	var FLYING_DUST_GRAVITY = 2
	vel.y += delta * FLYING_DUST_GRAVITY
	var destPos = pos + (vel * delta * pixelSizeScale * 20)
	destPos = destPos.round()
	
	destPos.x = clamp(destPos.x, 0, pixelWorldSizeX-1)
	destPos.y = clamp(destPos.y, 0, pixelWorldSizeY-1)
	
	var destPosType = GetPixel(destPos)
	if destPosType == PixelType.EMPTY or destPosType == PixelType.KILL:
		MovePixel(pos, destPos, image)
		
	var hitOtherDust = destPosType == PixelType.DUST or destPosType == PixelType.FLYING_DUST
	var hitCollision = destPosType == PixelType.COLLISION
	var hitScreenEdge = destPos.x == 0 or destPos.y == 0 or destPos.y == pixelWorldSizeX-1 or destPos.x == pixelWorldSizeX-1
	if hitOtherDust or hitCollision or hitScreenEdge:
		SetPixel(destPos, PixelType.DUST)
		vel = Vector2.ZERO
	
	ActivateRegion(pos)		
	ActivateRegion(destPos)	
	pixelVelocity[(destPos.y * pixelWorldSizeX) + destPos.x] = vel
	pixelVelocity[(pos.y * pixelWorldSizeX) + pos.x] = Vector2.ZERO

func UpdateDustPixelSim(pos, image):
	var movePos = null
	
	var downPos = Vector2(pos.x, pos.y + 1)
	var downClear = IsPositionFreeToMove(downPos)
	
	if downClear:
		var randNum = randi() % 15
		if randNum == 1:
			var leftPos = Vector2(pos.x - 1, pos.y)
			var rightPos = Vector2(pos.x + 1, pos.y)
			var randLR = randi() % 2
			if randLR == 1:
				if IsPositionFreeToMove(leftPos):
					movePos = leftPos
				elif IsPositionFreeToMove(rightPos):
					movePos = rightPos
			else:
				if IsPositionFreeToMove(rightPos):
					movePos = rightPos
				elif IsPositionFreeToMove(leftPos):
					movePos = leftPos

	if !movePos:
		var downRightPos = Vector2(pos.x + 1, pos.y + 1)
		var downLeftPos = Vector2(pos.x - 1, pos.y + 1)
		
		if downClear:
			movePos = downPos
		elif IsPositionFreeToMove(downRightPos):
			movePos = downRightPos
		elif IsPositionFreeToMove(downLeftPos):
			movePos = downLeftPos
		
	if movePos:
		MovePixel(pos, movePos, image)


# One idea is we could get rid of delta by running in fixed time steps
#	So in sim, accumulate the delta and once bigger than a fixedTimeStep, run the sim.
func UpdateSim(delta):
	var image = sprite.get_texture().get_data()
	image.lock()
	
	# do the forces stuff first
	if forceCount > 0:
		ApplyForce(forcePos, image)
		if forceCount % 2 == 0:
			if forceRight:
				forcePos.x = min(forcePos.x + 1, pixelWorldSizeX - 1)
			else:
				forcePos.x = max(forcePos.x - 1, 0)
		forceCount -= 1
	
	#print("-- simStages starting -- ")
	#var stagesStartTimeUSec = Time.get_ticks_usec()
	
	# flip the buffers, double buffer'in and all that
	var oldActiveBufferNum = activeRegionsBufferNum
	activeRegionsBufferNum = nextRegionsBufferNum
	nextRegionsBufferNum = oldActiveBufferNum
	checkRegionsBuffers[nextRegionsBufferNum].fill(null)
	
	pixelState.fill(false)
	
	var regionsBuffer = checkRegionsBuffers[activeRegionsBufferNum]
	
	
	var regionFinalIndex = totalRegionCount - 1
	for regionIndex in range(regionFinalIndex, -1, -1):
		var dirtyRect = regionsBuffer[regionIndex]
			
		#first check if this is active and we even need to do it
		if dirtyRect:
			dirtyRect.minX -= DIRTY_RECT_BOUNDARY
			dirtyRect.maxX += DIRTY_RECT_BOUNDARY
			dirtyRect.minY -= DIRTY_RECT_BOUNDARY
			dirtyRect.maxY += DIRTY_RECT_BOUNDARY

			var startX = max(0, dirtyRect.minX)
			var startY = max(0, dirtyRect.minY)
			var endX = min(pixelWorldSizeX-1, dirtyRect.maxX)
			var endY = min(pixelWorldSizeY-1, dirtyRect.maxY)
			
			if startX > endX or startY > endY:
				print("ERROR in dirtyRect, not normalised - ", startX, ", ", startY, ", ", endX, ", ", endY)
				continue
			
			# starts at the bottom of the screen so falling pixels only update once
			var yPos = endY
			while yPos >= startY: 
				var xPos = startX
				while xPos <= endX:
					var pos = Vector2(xPos, yPos)
					var pixelVisited = GetPixelState(pos)
					var pixelType = GetPixel(pos)
					if !pixelVisited:
						if pixelType == PixelType.DUST:
							UpdateDustPixelSim(pos, image)
						elif pixelType == PixelType.FLYING_DUST:
							UpdateFlyingDustPixel(pos, delta, image)
					SetPixelState(pos, true)
					xPos += 1
				yPos -= 1
		
		#var stagesTimeMS = Global.USecToMSec(Time.get_ticks_usec() - stageStartTimeUSec)
		#print("- EndStageNum - ", stageNum, ", timeTaken:", stagesTimeMS)
	
	#var allStagesTimeTakenMS = Global.USecToMSec(Time.get_ticks_usec() - stagesStartTimeUSec)
	#print("-- simStages finished -- timeTaken: ", allStagesTimeTakenMS)
	
	image.unlock()
	sprite.get_texture().set_data(image)

func ScreenPosToSimPos(screenPos):
	var unscaledX = screenPos.x / 2
	var unscaledY = screenPos.y / 2
	var pos = Vector2(unscaledX, unscaledY)
	var simPos = GetSimPos(pos)
	return simPos

func _input(event):
	if event is InputEventScreenTouch:
		if event.is_pressed():
			var simPos = ScreenPosToSimPos(event.position)
			CreateBulkDust(simPos)

func _process(event):
	var mousePos = get_viewport().get_mouse_position()
	var simPos = ScreenPosToSimPos(mousePos)
	
	if Input.is_action_just_pressed("debug_button_2"):
		enabledDebugDrawCollision = !enabledDebugDrawCollision
			
	if Input.is_action_just_pressed("debug_button_4"):
		enabledDebugDrawDirtyRects = !enabledDebugDrawDirtyRects
		
	if Input.is_action_pressed("fire_dust"):
		FireDust(simPos, true)
	elif Input.is_action_pressed("spawn_bulk_pixels"):
		CreateBulkDust(simPos)
	elif Input.is_action_pressed("spawn_pixel"):
		CreateDust([simPos])

func ApplyForce(pos, image):
	# -     #
	# -    ##      RIGHT EXAMPLE
	# -   ###      # = pixels to attempt to move
	# -  ####      @ = passed in pos
	# - @####
	var mod = 1 # left
	if forceRight:
		mod = -1 # right
	
	var sweepHeight : int = 16 / Global.DUST_SCALE
	var checkNum = 1
	var xStart = pos.x - ((sweepHeight - 1) * mod)
	var yStart = pos.y - (sweepHeight - 1)
	for y in range(yStart, yStart+sweepHeight, 1):
		var c = 1
		for x in range(xStart, xStart+(sweepHeight * mod), mod):
			if c <= checkNum:
				var currentPos = Vector2(x, y)
				
				if FIRE_DUST_TEST:
					if randi() % 4 == 0:
						var dirUpPos = Vector2(-mod, -1)
						FireDustInDir(currentPos, dirUpPos, false)
						continue
					
				if GetPixel(currentPos) == PixelType.DUST:
					var xMod = mod
					if Global.DUST_SCALE == 1:
						xMod = mod * 2
					var dirPos = Vector2(x-xMod, y)
					var dirUpPos = Vector2(x-xMod, y-1)
					var dirUpUpPos = Vector2(x-xMod, y-2)

					if IsPositionFreeToMove(dirPos):
						MovePixel(currentPos, dirPos, image)
					elif IsPositionFreeToMove(dirUpPos):
						MovePixel(currentPos, dirUpPos, image)
					elif IsPositionFreeToMove(dirUpUpPos):
						MovePixel(currentPos, dirUpUpPos, image)
			c += 1
		checkNum += 1

func IsPositionEmpty(pos):
	if !IsInBounds(pos):
		return false
	var posType = GetPixel(pos)
	return posType == PixelType.EMPTY

func IsPositionFreeToMove(pos):
	if !IsInBounds(pos):
		return false
	var posType = GetPixel(pos)
	return posType == PixelType.EMPTY or posType == PixelType.KILL
	
func ConvertRegionIndexToPosStart(rIndex):
	var x = (rIndex % regionWorldSizeX) * REGION_SIZE
	var y = floor(rIndex / regionWorldSizeX) * REGION_SIZE
	return Vector2(x, y)

func _on_sweep(pos, facingRight):
	forcePos = GetSimPos(pos)
	forceCount = FORCE_COUNT
	forceRight = facingRight

func GetSimPos(pos):
	var simPosX = floor(pos.x / pixelSizeScale)
	var simPosY = floor(pos.y / pixelSizeScale)
	return Vector2(simPosX, simPosY)

func _physics_process(delta):
	UpdateSim(delta)
	update()

func _draw():
	if enabledDebugDrawCollision:
		var rectSize = Vector2(pixelSizeScale, pixelSizeScale)
		var pixelFinalIndex = (pixelWorldSizeX * pixelWorldSizeY) - 1
		for i in range(pixelFinalIndex, -1, -1):
			if pixelTypes[i] == PixelType.COLLISION or pixelTypes[i] == PixelType.KILL:
				var x = (i % pixelWorldSizeX) * pixelSizeScale
				var y = floor(i / pixelWorldSizeX) * pixelSizeScale
				var pos = Vector2(x, y)
				var rect = Rect2(pos, rectSize)
				var c = Color(0, 1, 1, 0.9)
				if pixelTypes[i] == PixelType.KILL:
					c = Color(1, 1, 0, 0.9)
				draw_rect(rect, c, true)
	
	if enabledDebugDrawDirtyRects:
		var regionSize = Vector2(REGION_SIZE * pixelSizeScale, REGION_SIZE * pixelSizeScale)
		var regionFinalIndex = (regionWorldSizeX * regionWorldSizeY) - 1
		for i in range(regionFinalIndex, -1, -1):
			var posStart = ConvertRegionIndexToPosStart(i)

			var scaledPos = Vector2(posStart.x * pixelSizeScale, posStart.y * pixelSizeScale)
			var rect = Rect2(scaledPos, regionSize)
			var regionBuffer = checkRegionsBuffers[activeRegionsBufferNum]
			var regionDirtyRect = regionBuffer[i]
			if regionDirtyRect:
				draw_rect(rect, Color.gray, false)

				var dirtyRect = regionDirtyRect
				var drawDirtyRect = Rect2()
				drawDirtyRect.position.x = dirtyRect.minX * pixelSizeScale
				drawDirtyRect.position.y = dirtyRect.minY * pixelSizeScale
				drawDirtyRect.end.x = (dirtyRect.maxX + 1) * pixelSizeScale
				drawDirtyRect.end.y = (dirtyRect.maxY + 1) * pixelSizeScale
				draw_rect(drawDirtyRect, Color.yellow, false)
			else:
				draw_rect(rect, Color.black, false)
