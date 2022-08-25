extends Node2D

export(Array, Color) var dustColors = [
	Color(0.368627, 0.796078, 0.407843, 1),
	Color(0.0823529, 0.447059, 0.113725, 1),
	Color(0.0705882, 0.392157, 0.0980392, 1),
	Color(0.0534668, 0.285156, 0.0734209, 1)
]
export(Array, Color) var lavaColors = [Color.red, Color.brown, Color.crimson, Color.darkred]
export(Array, Color) var smokeColors = [Color.black]

enum PixelType {
	EMPTY
	DUST
	FLYING_DUST
	LAVA
	FLYING_LAVA
	SMOKE
	COLLISION
}

onready var sprite_2x : Sprite = $Sprite_2x
onready var sprite_4x : Sprite = $Sprite_4x
var sprite : Sprite # set in _ready

const FIRE_DUST_TEST = false
var FLYING_DUST_GRAVITY = 2
var FLYING_LAVA_GRAVITY = 3

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
	Events.connect("spawn_lava", self, "_on_spawn_lava")
	
	if Global.DUST_SCALE == 1:
		sprite = sprite_2x
	elif Global.DUST_SCALE == 2:
		sprite = sprite_4x
	else:
		assert(false) # bad DUST_SCALE value!
	
	sprite.visible = true
	pixelSizeScale = Global.DUST_SIZE
	
	pixelWorldSizeX = int(float(worldSizeX) / pixelSizeScale)
	pixelWorldSizeY = int(float(worldSizeY) / pixelSizeScale)
	
	assert(REGION_SIZE % 2 == 0) # pls, just don't make uneven
	
	#regionWorldSizeX = pixelWorldSizeX / REGION_SIZE
	#regionWorldSizeY = pixelWorldSizeY / REGION_SIZE
	regionWorldSizeX = int(ceil(pixelWorldSizeX as float / REGION_SIZE as float))
	regionWorldSizeY = int(ceil(pixelWorldSizeY as float / REGION_SIZE as float))
	
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
	Events.disconnect("spawn_lava", self, "_on_spawn_lava")

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
	
	var lavaPositions = []
	for i in range(0, pixelTypes.size()):
		var testPos = Vector2()
		testPos.x = ((i % pixelWorldSizeX) * pixelSizeScale) + 1
		testPos.y = (floor(i / float(pixelWorldSizeX)) * pixelSizeScale) + 1
		
		var collisions = space_state.intersect_point(testPos)
		for col in collisions:
			var collider = col.collider
			if collider.is_in_group("player") or collider.is_in_group("ladder_top"):
				continue
			
			if collider.is_in_group("dust_kill"):
				var simPos = GetSimPos(testPos)
				lavaPositions.push_back(simPos)
			else:
				pixelTypes[i] = PixelType.COLLISION
	CreatePixels(lavaPositions, PixelType.LAVA)

func _on_spawn_dust(pos, amount):
	var simPos = GetSimPos(pos)
	var positions = []
	var xStart = simPos.x - floor(amount / 2)
	var yStart = simPos.y - amount
	for x in range(0, amount):
		for y in range(0, amount):
			positions.push_back(Vector2(xStart + x, yStart + y))
	CreatePixels(positions, PixelType.DUST)

func _on_spawn_lava(pos, makeFlying, flyingVelocity):
	var startPos = GetSimPos(pos)
	if makeFlying:
		FirePixelInDir(startPos, flyingVelocity, PixelType.LAVA, true)
	else:
		var positions = []
		positions.push_back(startPos)
		CreatePixels(positions, PixelType.LAVA)

func GetPixelTypeColor(type):
	var colorArray
	if type == PixelType.DUST or type == PixelType.FLYING_DUST:
		colorArray = dustColors
	elif type == PixelType.LAVA or type == PixelType.FLYING_LAVA:
		colorArray = lavaColors	
	elif type == PixelType.SMOKE:
		colorArray = smokeColors
	assert(colorArray)
	
	var randIdx = randi() % colorArray.size()
	var color = colorArray[randIdx]
	return color

func FirePixel(pos, type, canMakeDust):
	var xRand = randf()
	var velX = -xRand if randi() % 2 else xRand
	var velY = -randf()
	var vel = Vector2(velX, velY)
	vel = vel.normalized()
	FirePixelInDir(pos, vel, type, canMakeDust)

func FirePixelInDir(pos, vel, type, canMakeDust):
	# pick a random direction from simPos and fire it with a fixed velocity
	
	var pixelType = GetPixel(pos)
	if !canMakeDust and pixelType != type:
		return
	if canMakeDust and pixelType != PixelType.EMPTY:
		return
	
	var flyingType
	if type == PixelType.DUST:
		flyingType = PixelType.FLYING_DUST
	elif type == PixelType.LAVA:
		flyingType = PixelType.FLYING_LAVA
	else:
		assert(false, "no flying type for that")
	
	SetPixel(pos, flyingType)
	pixelVelocity[(pos.y * pixelWorldSizeX) + pos.x] = vel
	
	var image = sprite.get_texture().get_data()
	image.lock()
	
	if pixelType == PixelType.EMPTY:
		var color = GetPixelTypeColor(type)
		image.set_pixelv(pos, color)
		ActivateRegion(pos)
		Global.DustRemaining += 1
		Events.emit_signal("dust_amount_changed", 1)
	
	image.unlock()
	sprite.get_texture().set_data(image)
	
func CreatePixels(positions, type):
	var dustCreated : int = 0
	var image = sprite.get_texture().get_data()
	image.lock()
		
	for pos in positions:
		if !IsPositionEmpty(pos):
			continue
			
		#print("CreateDust xPos:", pos.x, ", yPos:", pos.y)
		SetPixel(pos, type)
		
		var color = GetPixelTypeColor(type)
		image.set_pixelv(pos, color)
		
		if type == PixelType.DUST:
			dustCreated += 1
	
	image.unlock()
	sprite.get_texture().set_data(image)
	Global.DustRemaining += dustCreated
	Events.emit_signal("dust_amount_changed", dustCreated)
	#print("Dust remaining: " + str(Global.DustRemaining))

func CreateBulkPixels(pos, type):
	var positions = [pos]
	positions.push_back(Vector2(pos.x - (randi() % 10), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x + (randi() % 10), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x + (randi() % 12), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x - (randi() % 12), pos.y - (randi() % 14)))
	CreatePixels(positions, type)

func IsInBounds(pos):
	var inXBounds = pos.x < pixelWorldSizeX and pos.x >= 0
	var inYBounds = pos.y < pixelWorldSizeY and pos.y >= 0
	return inXBounds and inYBounds

func KillDust(pos, image):
	#print("KillDust-pos:", pos, ", stack:", get_stack())
	Global.DustRemaining -= 1 # destroy dust
	Events.emit_signal("dust_amount_changed", -1)
	
	var smokePos = Vector2(pos.x, pos.y - 1)
	if IsPositionEmpty(smokePos):
		SetPixel(smokePos, PixelType.SMOKE)
		
		var color = GetPixelTypeColor(PixelType.SMOKE)
		image.set_pixelv(smokePos, color)
	
func MovePixel(srcPos, destPos, srcType, image):
	if srcType == PixelType.DUST or srcType == PixelType.FLYING_DUST:
		var destPosType = GetPixel(destPos)
		assert(destPosType != PixelType.COLLISION and destPosType != PixelType.DUST and destPosType != PixelType.FLYING_DUST)
		
		if destPosType == PixelType.EMPTY:
			SetPixel(destPos, GetPixel(srcPos)) # move dust
			image.set_pixelv(destPos, image.get_pixelv(srcPos))
			
		SetPixel(srcPos, PixelType.EMPTY)
		image.set_pixelv(srcPos, Color.transparent)
		
		if destPosType != PixelType.EMPTY:
			KillDust(srcPos, image)
	
	elif srcType == PixelType.LAVA or srcType == PixelType.FLYING_LAVA:
		var destPosType = GetPixel(destPos)
		assert(destPosType != PixelType.COLLISION and destPosType != PixelType.LAVA and destPosType != PixelType.FLYING_LAVA)
		
		SetPixel(destPos, GetPixel(srcPos)) # move dust
		image.set_pixelv(destPos, image.get_pixelv(srcPos))

		SetPixel(srcPos, PixelType.EMPTY)
		image.set_pixelv(srcPos, Color.transparent)
		
		if destPosType == PixelType.DUST or destPosType == PixelType.FLYING_DUST:
			KillDust(destPos, image)
		
	elif srcType == PixelType.SMOKE:
		var destPosType = GetPixel(destPos)
		if destPosType == PixelType.EMPTY:
			SetPixel(destPos, GetPixel(srcPos)) # move smoke
			image.set_pixelv(destPos, image.get_pixelv(srcPos))
		SetPixel(srcPos, PixelType.EMPTY)
		image.set_pixelv(srcPos, Color.transparent)

# return the lastValidPosition
func MoveAndCollide(pos, moveVec, collideTypeArray, stopAtBoundary):
	var x = pos.x
	var y = pos.y
	var stepX = -1 if moveVec.x < 0 else 1
	var stepY = -1 if moveVec.y < 0 else 1
	var xLeft = floor(abs(moveVec.x))
	var yLeft = floor(abs(moveVec.y))
	
	var testPos = pos
	var lastValidPos = pos	
	var targetPos = pos + moveVec
	
	var lastCollisionType = PixelType.EMPTY
	var colliderPos = null
	var hitBoundary = false
	
	
	#print("--new test-- pos:", pos, ", moveVec:", moveVec, ", targetPos:", targetPos)
	while testPos != targetPos:
		if xLeft >= yLeft:
			xLeft -= 1
			x += stepX
		else:
			yLeft -= 1
			y += stepY
		testPos = Vector2(x, y)
		#print("testPos - ", testPos)
		var inBounds = IsInBounds(testPos)
		if stopAtBoundary and !inBounds:
			hitBoundary = true
			break
			
		if inBounds:
			var testPosType = GetPixel(testPos)
			for collideType in collideTypeArray:
				if testPosType == collideType:
					colliderPos = testPos
					lastCollisionType = collideType 
					break
			if lastCollisionType != PixelType.EMPTY:
				break
		lastValidPos = testPos
		
	#print("lastValidPos:", lastValidPos, ", lastCollisionType:", lastCollisionType)
	return { 
		lastValidPos = lastValidPos, 
		lastCollisionType = lastCollisionType,
		colliderPos = colliderPos,
		hitBoundary = hitBoundary
	}
	
#func MoveAndCollideBox(minX, maxX, minY, maxY, moveVec, collideTypeArray, stopAtBoundary):
#	var moveA = MoveAndCollide(Vector2(minX, minY), moveVec, collideTypeArray, stopAtBoundary)	
#	var moveB = MoveAndCollide(Vector2(maxX, minY), moveVec, collideTypeArray, stopAtBoundary)
#	var moveC = MoveAndCollide(Vector2(minX, maxY), moveVec, collideTypeArray, stopAtBoundary)
#	var moveD = MoveAndCollide(Vector2(maxX, maxY), moveVec, collideTypeArray, stopAtBoundary)
#
#
#
#	var collisionTypes = Array()
#	collisionTypes.append_array(moveA.collisionTypes)
#	collisionTypes.append_array(moveB.collisionTypes)
#	collisionTypes.append_array(moveC.collisionTypes)
#	collisionTypes.append_array(moveD.collisionTypes)
#
#	var hitBoundary = moveA.hitBoundary or moveC.hitBoundary or moveC.hitBoundary or moveD.hitBoundary
#
#	var resultMove = {
#		lastValidPos = lastValidPos,
#		collisionTypes = collisionTypes,
#		hitBoundary = hitBoundary
#	}

func GetFlyingPixelsCollidingType(type):
	assert(type == PixelType.FLYING_DUST or type == PixelType.FLYING_LAVA)
	if type == PixelType.FLYING_DUST:
		return [PixelType.COLLISION, PixelType.DUST, PixelType.FLYING_DUST]
	elif type == PixelType.FLYING_LAVA:
		return [PixelType.COLLISION, PixelType.LAVA, PixelType.FLYING_LAVA]

func UpdateFlyingPixel(pos, pixelType, delta, image):
	var vel = pixelVelocity[(pos.y * pixelWorldSizeX) + pos.x]
	
	# apply gravity
	var gravity
	match pixelType:
		PixelType.FLYING_DUST:
			gravity = FLYING_DUST_GRAVITY
		PixelType.FLYING_LAVA:
			gravity = FLYING_LAVA_GRAVITY
	
	vel.y += delta * gravity
	
	var moveVec = vel * delta * pixelSizeScale * 20
	moveVec = moveVec.round()
	
	var collideTypes = GetFlyingPixelsCollidingType(pixelType)
	var collideWithBoundary = true
	var moveResult = MoveAndCollide(pos, moveVec, collideTypes, collideWithBoundary)
	
	var destPos = moveResult.lastValidPos
	var isMovement = pos != destPos
	
	var destPosType = GetPixel(destPos)

	if isMovement:
		MovePixel(pos, destPos, pixelType, image)
		ActivateRegion(destPos)

	ActivateRegion(pos)
	
	var collideType = moveResult.lastCollisionType
	if collideType != PixelType.EMPTY:
		var colliderPos = moveResult.colliderPos
		
		if pixelType == PixelType.FLYING_LAVA:
			var hitLava = collideType == PixelType.LAVA
			var hitCollision = collideType == PixelType.COLLISION
			var hitBoundary = moveResult.hitBoundary
			
			if hitLava or hitCollision or hitBoundary:
				SetPixel(destPos, PixelType.LAVA)
				vel = Vector2.ZERO
				
		elif pixelType == PixelType.FLYING_DUST:
			var hitDust = collideType == PixelType.DUST or collideType == PixelType.FLYING_DUST
			var hitCollision = collideType == PixelType.COLLISION
			var hitBoundary = moveResult.hitBoundary
			
			if hitDust or hitCollision or hitBoundary:
				SetPixel(destPos, PixelType.DUST)
				vel = Vector2.ZERO
	
	pixelVelocity[(pos.y * pixelWorldSizeX) + pos.x] = Vector2.ZERO
	pixelVelocity[(destPos.y * pixelWorldSizeX) + destPos.x] = vel

func UpdateDustPixel(pos, image):
	var movePos = null
	
	var downPos = Vector2(pos.x, pos.y + 1)
	var downClear = IsPositionFreeForDust(downPos)
	
	if downClear:
		var randNum = randi() % 15
		if randNum == 1:
			var leftPos = Vector2(pos.x - 1, pos.y)
			var rightPos = Vector2(pos.x + 1, pos.y)
			var randLR = randi() % 2
			if randLR == 1:
				if IsPositionFreeForDust(leftPos):
					movePos = leftPos
				elif IsPositionFreeForDust(rightPos):
					movePos = rightPos
			else:
				if IsPositionFreeForDust(rightPos):
					movePos = rightPos
				elif IsPositionFreeForDust(leftPos):
					movePos = leftPos

	if !movePos:
		var downRightPos = Vector2(pos.x + 1, pos.y + 1)
		var downLeftPos = Vector2(pos.x - 1, pos.y + 1)
		
		if downClear:
			movePos = downPos
		elif IsPositionFreeForDust(downRightPos):
			movePos = downRightPos
		elif IsPositionFreeForDust(downLeftPos):
			movePos = downLeftPos
		
	if movePos:
		MovePixel(pos, movePos, PixelType.DUST, image)

func UpdateSmokePixel(pos, image):
	var movePos = null
	
	# random chance to go upleft or upright
	var randNum = randi() % 100
	if randNum > 75:
		ActivateRegion(pos) # dont update this round but still activate
		return
	if randNum < 15:
		var randLeftRight = -1 if randi() % 2 == 0 else 1
		var upLeftRightPos = Vector2(pos.x + randLeftRight, pos.y - 1)
		# only move left or right if its empty. Else we'd rather go up 
		if IsPositionEmpty(upLeftRightPos): 
			movePos = upLeftRightPos
	
	var upPos = Vector2(pos.x, pos.y - 1)
	if !movePos and IsInBounds(upPos):
		movePos = upPos
		
	if movePos:
		MovePixel(pos, movePos, PixelType.SMOKE, image)

func UpdateLavaPixel(pos, image):
	var movePos = null
	
	var vel = 3
	
	while vel > 0 and movePos == null:
		var downPos = Vector2(pos.x, pos.y + vel)
		var downRightPos = Vector2(pos.x + 1, pos.y + vel)
		var downLeftPos = Vector2(pos.x - 1, pos.y + vel)
		
		var randLeftRight = -vel if randi() % 2 == 0 else vel
		var leftOrRightPos = Vector2(pos.x + randLeftRight, pos.y)
		
		if IsPositionFreeForLava(downPos):
			movePos = downPos
		elif IsPositionFreeForLava(downRightPos):
			movePos = downRightPos
		elif IsPositionFreeForLava(downLeftPos):
			movePos = downLeftPos
		elif IsPositionFreeForLava(leftOrRightPos):
			movePos = leftOrRightPos
		
		vel -= 1
	
	if movePos:
		MovePixel(pos, movePos, PixelType.LAVA, image)


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
							UpdateDustPixel(pos, image)
						elif pixelType == PixelType.FLYING_DUST:
							UpdateFlyingPixel(pos, pixelType, delta, image)
						elif pixelType == PixelType.SMOKE:
							UpdateSmokePixel(pos, image)
						elif pixelType == PixelType.LAVA:
							UpdateLavaPixel(pos, image)
						elif pixelType == PixelType.FLYING_LAVA:
							UpdateFlyingPixel(pos, pixelType, delta, image)
							pass
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

func ApplyForce(pos, image):
	# -     #
	# -    ##      RIGHT EXAMPLE
	# -   ###      # = pixels to attempt to move
	# -  ####      @ = passed in pos
	# - @####
	var mod = 1 # left
	if forceRight:
		mod = -1 # right
	
	var sweepHeight : int = int(16.0 / Global.DUST_SCALE)
	var checkNum = 1
	var xStart = pos.x - ((sweepHeight - 1) * mod)
	var yStart = pos.y - (sweepHeight - 1)
	for y in range(yStart, yStart+sweepHeight, 1):
		var c = 1
		for x in range(xStart, xStart+(sweepHeight * mod), mod):
			if c <= checkNum:
				var maxPower = (randi() % 4) + 3
				var power = max((maxPower - c), 1)
				var currentPos = Vector2(x, y)
				
				if FIRE_DUST_TEST:
					if randi() % 4 == 0:
						var dirUpPos = Vector2(-mod, -1)
						FirePixelInDir(currentPos, dirUpPos, PixelType.DUST, false)
						continue
					
				if GetPixel(currentPos) == PixelType.DUST:
					var xMod = mod * power
					if Global.DUST_SCALE == 1:
						xMod = mod * 2
					var dirPos = Vector2(x-xMod, y)
					var dirUpPos = Vector2(x-xMod, y-1)
					var dirUpUpPos = Vector2(x-xMod, y-2)

					if IsPositionFreeForDust(dirPos):
						MovePixel(currentPos, dirPos, PixelType.DUST, image)
					elif IsPositionFreeForDust(dirUpPos):
						MovePixel(currentPos, dirUpPos, PixelType.DUST, image)
					elif IsPositionFreeForDust(dirUpUpPos):
						MovePixel(currentPos, dirUpUpPos, PixelType.DUST, image)
			c += 1
		checkNum += 1

func IsPositionFreeForLava(pos):
	if !IsInBounds(pos):
		return false
	var posType = GetPixel(pos)
	return posType != PixelType.COLLISION and posType != PixelType.LAVA and posType != PixelType.FLYING_LAVA

func IsPositionEmpty(pos):
	if !IsInBounds(pos):
		return false
	var posType = GetPixel(pos)
	return posType == PixelType.EMPTY

func IsPositionFreeForDust(pos):
	if !IsInBounds(pos):
		return false
	var posType = GetPixel(pos)
	return posType == PixelType.EMPTY or posType == PixelType.LAVA or posType == PixelType.FLYING_LAVA
	
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

func _input(event):
	if event is InputEventScreenTouch:
		if event.is_pressed():
			var simPos = ScreenPosToSimPos(event.position)
			CreateBulkPixels(simPos, PixelType.DUST)

func _process(event):
	var mousePos = get_viewport().get_mouse_position()
	var simPos = ScreenPosToSimPos(mousePos)
	
	if Input.is_action_just_pressed("debug_button_2"):
		enabledDebugDrawCollision = !enabledDebugDrawCollision
			
	if Input.is_action_just_pressed("debug_button_4"):
		enabledDebugDrawDirtyRects = !enabledDebugDrawDirtyRects
		
	if Input.is_action_pressed("fire_dust"):
		FirePixel(simPos, PixelType.LAVA, true)
	elif Input.is_action_pressed("spawn_bulk_pixels"):
		CreateBulkPixels(simPos, PixelType.DUST)
	elif Input.is_action_pressed("spawn_pixel"):
		CreatePixels([simPos], PixelType.LAVA)

func _physics_process(delta):
	UpdateSim(delta)
	update()

func _draw():
	if enabledDebugDrawCollision:
		var rectSize = Vector2(pixelSizeScale, pixelSizeScale)
		var pixelFinalIndex = (pixelWorldSizeX * pixelWorldSizeY) - 1
		for i in range(pixelFinalIndex, -1, -1):
			if pixelTypes[i] == PixelType.COLLISION or pixelTypes[i] == PixelType.LAVA:
				var x = (i % pixelWorldSizeX) * pixelSizeScale
				var y = floor(i / float(pixelWorldSizeX)) * pixelSizeScale
				var pos = Vector2(x, y)
				var rect = Rect2(pos, rectSize)
				var c = Color(0, 1, 1, 0.9)
				if pixelTypes[i] == PixelType.LAVA:
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
