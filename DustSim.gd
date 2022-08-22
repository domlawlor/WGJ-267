extends Node2D

export(Color) var dustColourA
export(Color) var dustColourB
export(Color) var dustColourC
export(Color) var dustColourD

enum PixelType {
	EMPTY
	DUST
	COLLISION
}

const USE_THREAD_VERSION = false

# pick pixel scale size here
onready var sprite : Sprite = $Sprite_4x
#onready var sprite : Sprite = $Sprite_2x

onready var colTest : KinematicBody2D = $CollisionTestArea

var worldSizeX : int = 640
var worldSizeY : int = 480

var pixelSizeScale : int
var pixelWorldSizeX : int
var pixelWorldSizeY : int
var pixelTypes = []

var REGION_SIZE = 8
var regionWorldSizeX : int
var regionWorldSizeY : int

var checkRegions = []

## Threading data
const simStageCount = 4 # always will be 4 for checkboarding. No more, no less
var simStages = [[],[],[],[]] # 4 stages, with regionGrid positions to be filled in each

const THREAD_COUNT = 16

var simThreads = []
var simThreadsData = []

var activeRegionsBufferNum = 0
var nextRegionsBufferNum = 1
var checkRegionsBuffers = [[], []]
#var nextCheckRegions = [] #TODO Double buffer these two

var regionHalfSizeX : int
var regionHalfSizeY : int

var regionGridTotal : int
#####

var FORCE_COUNT = 20
var forceCount = 0
var forcePos : Vector2 = Vector2.ZERO
var forceRight = true

func _ready():
	Events.connect("sweep", self, "_on_sweep")
	Events.connect("spawn_dust", self, "_on_spawn_dust")
	
	sprite.visible = true
	pixelSizeScale = sprite.scale.x
	
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
	
	regionGridTotal = regionWorldSizeX * regionWorldSizeY
	
	print("TextureSize-", sprite.get_texture().get_size())
	print("Image-", sprite.get_texture().get_data().get_size())
	ClearWorld()
	SetLevelCollisions()
	
	if USE_THREAD_VERSION:
		# setup the checkboarding positions we use each stage
		for yPos in range(regionWorldSizeY):
			for xPos in range(regionWorldSizeX):
				var gridPos = Vector2(xPos, yPos)
				var xEven = (xPos % 2) == 0
				var yEven = (yPos % 2) == 0
				if xEven and yEven:
					simStages[0].push_back(gridPos)
				elif xEven and !yEven:
					simStages[1].push_back(gridPos)
				elif !xEven and yEven:
					simStages[2].push_back(gridPos)
				elif !xEven and !yEven:
					simStages[3].push_back(gridPos)
		
		for threadNum in range(THREAD_COUNT):
			var thread = Thread.new()
			var result = thread.start(self, "_thread_function", threadNum, Thread.PRIORITY_HIGH)
			assert(result == OK)
			simThreads.push_back(thread)
			
			simThreadsData.push_back({
				stopQueued = false,
				idle = true,
				startWorkSemaphore = Semaphore.new(),
				regionWorkData = []
			})
		
		

# TODO: Pull these values from elsewhere
# TODO: also this fixes us to one screens worth of pixels. 
#		Change in future to bigger world, only updating whats close to the player

func _exit_tree():
	CleanupThreads()

func CleanupThreads():
	for threadData in simThreadsData:
		threadData.stopQueued = true
		threadData.workData = [] # clean out any work somehow still here
		threadData.startWorkSemaphore.post()
	
	var threadLastIdx = simThreads.size()-1
	
	var threadsDone = false
	while !threadsDone:
		threadsDone = true
		for thread in simThreads:
			threadsDone = threadsDone and thread.is_alive()
		
	for thread in simThreads:	
		thread.wait_to_finish()	
	simThreads = []

func GetPixel(pos):
	return pixelTypes[(pos.y * pixelWorldSizeX) + pos.x]

func SetPixel(pos, type):
	pixelTypes[(pos.y * pixelWorldSizeX) + pos.x] = type
	ActivateRegion(pos)
	
	#
	if false and USE_THREAD_VERSION:
		ActivateRegion(Vector2(pos.x, pos.y + 1))
		ActivateRegion(Vector2(pos.x, pos.y - 1))
		ActivateRegion(Vector2(pos.x + 1, pos.y))
		ActivateRegion(Vector2(pos.x + 1, pos.y + 1))
		ActivateRegion(Vector2(pos.x + 1, pos.y - 1))
		ActivateRegion(Vector2(pos.x - 1, pos.y))
		ActivateRegion(Vector2(pos.x - 1, pos.y + 1))
		ActivateRegion(Vector2(pos.x - 1, pos.y - 1))

func ActivateRegion(pos):
	var regX = floor(pos.x / REGION_SIZE)
	var regY = floor(pos.y / REGION_SIZE)
	var regIndex : int = regY * regionWorldSizeX + regX
	
	if USE_THREAD_VERSION:
		#if regIndex < 0 or regIndex > regionGridTotal:
		#	return
		
		var regionBuffer = checkRegionsBuffers[nextRegionsBufferNum]
		var region = regionBuffer[regIndex]
		
		var dirtyRect = region.dirtyRect
		assert(dirtyRect) 
		
		# stretch our dirty rect to fit our new pixel, plus a barrier of one around it
		var minX = max(0, min(dirtyRect.minX, pos.x))
		var minY = max(0, min(dirtyRect.minY, pos.y))
		var maxX = min(pixelWorldSizeX, max(dirtyRect.maxX, pos.x))
		var maxY = min(pixelWorldSizeY, max(dirtyRect.maxY, pos.y))
		
		regionBuffer[regIndex] = {
			active = true,
			dirtyRect = { minX = minX, minY = minY, maxX = maxX, maxY = maxY },
		}
		
	else:
		checkRegions[regIndex] = true #actual pos index
		
		var regionCount = regionWorldSizeX * regionWorldSizeY
		var checkLeft = (regIndex % regionWorldSizeX) > 0
		var checkRight = (regIndex % regionWorldSizeX) < (regionWorldSizeX - 1)
		var checkUp = regIndex >= regionWorldSizeX
		var checkDown = regIndex < regionCount - regionWorldSizeX
		
		if checkLeft and checkUp:
			checkRegions[regIndex - 1 - regionWorldSizeX] = true
		if checkUp:
			checkRegions[regIndex - regionWorldSizeX] = true
		if checkUp and checkRight:
			checkRegions[regIndex - regionWorldSizeX + 1] = true
		if checkLeft:
			checkRegions[regIndex - 1] = true
		if checkRight:
			checkRegions[regIndex + 1] = true
		if checkDown and checkLeft:
			checkRegions[regIndex + regionWorldSizeX - 1] = true
		if checkDown:
			checkRegions[regIndex + regionWorldSizeX] = true
		if checkDown and checkRight:
			checkRegions[regIndex + regionWorldSizeX + 1] = true

func ResetRegions(regions):
	regions.fill({ active = false, dirtyRect = {minX=pixelWorldSizeX, minY=pixelWorldSizeY, maxX=0, maxY=0}})

func ClearWorld():
	var pixelCount = pixelWorldSizeX * pixelWorldSizeY
	pixelTypes.resize(pixelCount)
	pixelTypes.fill(PixelType.EMPTY)
	
	var regionCount = regionWorldSizeX * regionWorldSizeY
	checkRegions.resize(regionCount)
	checkRegions.fill(true)
	
	if USE_THREAD_VERSION:
		for regionsBuffer in checkRegionsBuffers:
			regionsBuffer.resize(regionCount)
			ResetRegions(regionsBuffer)
	
	var image = sprite.get_texture().get_data()
	image.lock()
	image.fill(Color.transparent)
	image.unlock()
	sprite.get_texture().set_data(image)

func SetLevelCollisions():
	for i in range(0, pixelTypes.size()):
		colTest.position.x = ((i % pixelWorldSizeX) * pixelSizeScale) + 1
		colTest.position.y = (floor(i / pixelWorldSizeX) * pixelSizeScale) + 1
		var col = colTest.move_and_collide(Vector2.ZERO, true, true, true)
		if col != null:
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
	
	
func CreateDust(positions):
	var image = sprite.get_texture().get_data()
	image.lock()
	
	for pos in positions:
		if !IsInBounds(pos) or !IsPixelFree(pos):
			continue
		
		#print("CreateDust xPos:", pos.x, ", yPos:", pos.y)
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
		
		SetPixel(pos, PixelType.DUST)
		image.set_pixelv(pos, color)
	
	image.unlock()
	sprite.get_texture().set_data(image)

func CreateBulkDust(pos):
	var positions = [pos]
	positions.push_back(Vector2(pos.x - (randi() % 2), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x + (randi() % 4), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x - (randi() % 4), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x + (randi() % 2), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x + (randi() % 6), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x - (randi() % 6), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x - (randi() % 8), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x + (randi() % 8), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x - (randi() % 10), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x + (randi() % 10), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x + (randi() % 12), pos.y - (randi() % 14)))
	positions.push_back(Vector2(pos.x - (randi() % 12), pos.y - (randi() % 14)))
	CreateDust(positions)

func IsInBounds(pos):
	var inXBounds = pos.x < pixelWorldSizeX and pos.x >= 0
	var inYBounds = pos.y < pixelWorldSizeY and pos.y >= 0
	return inXBounds and inYBounds

func IsPixelFree(pos):
	return pixelTypes[(pos.y * pixelWorldSizeX) + pos.x] == PixelType.EMPTY
	
func MovePixel(srcPos, destPos, image):
	SetPixel(destPos, GetPixel(srcPos))
	SetPixel(srcPos, PixelType.EMPTY)
	
	# now move color
	image.set_pixelv(destPos, image.get_pixelv(srcPos))
	image.set_pixelv(srcPos, Color.transparent)
	#print("Moved pixel: ", srcPos, " to ", destPos)

func UpdateDustPixelSim(pos, image):
	var downPos = Vector2(pos.x, pos.y + 1)
	var downPosInBounds = IsInBounds(downPos)
	var downClear = downPosInBounds and GetPixel(downPos) == PixelType.EMPTY
	
	if downClear:
		var randNum = randi() % 15
		if randNum == 1:
			var leftPos = Vector2(pos.x - 1, pos.y)
			var rightPos = Vector2(pos.x + 1, pos.y)
			var leftPosInBounds = IsInBounds(leftPos)
			var rightPosInBounds = IsInBounds(rightPos)
			var randLR = randi() % 2
			if randLR == 1:
				if leftPosInBounds and GetPixel(leftPos) == PixelType.EMPTY:
					MovePixel(pos, leftPos, image)
				elif rightPosInBounds and GetPixel(rightPos) == PixelType.EMPTY:
					MovePixel(pos, rightPos, image)
			else:
				if rightPosInBounds and GetPixel(rightPos) == PixelType.EMPTY:
					MovePixel(pos, rightPos, image)
				elif leftPosInBounds and GetPixel(leftPos) == PixelType.EMPTY:
					MovePixel(pos, leftPos, image)
			return
	
	var downRightPos = Vector2(pos.x + 1, pos.y + 1)
	var downLeftPos = Vector2(pos.x - 1, pos.y + 1)
	
	var downRightPosInBounds = IsInBounds(downRightPos)
	var downLeftPosInBounds = IsInBounds(downLeftPos)
	
	if downClear:
		MovePixel(pos, downPos, image)
	elif downRightPosInBounds and GetPixel(downRightPos) == PixelType.EMPTY:
		MovePixel(pos, downRightPos, image)
	elif downLeftPosInBounds and GetPixel(downLeftPos) == PixelType.EMPTY:
		MovePixel(pos, downLeftPos, image)

# One idea is we could get rid of delta by running in fixed time steps
#	So in sim, accumulate the delta and once bigger than a fixedTimeStep, run the sim.
func UpdateSim(delta):
	var image = sprite.get_texture().get_data()
	image.lock()
	
	if forceCount > 0:
		ApplyForce(forcePos, image)
		if forceCount % 2 == 0:
			if forceRight:
				forcePos.x = min(forcePos.x + 1, pixelWorldSizeX - 1)
			else:
				forcePos.x = max(forcePos.x - 1, 0)
		forceCount -= 1
	
	var regionFinalIndex = (regionWorldSizeX * regionWorldSizeY) - 1
	for i in range(regionFinalIndex, -1, -1):
		if checkRegions[i]:
			checkRegions[i] = false
			var posStart = ConvertRegionIndexToPosStart(i)
			for yMod in range(REGION_SIZE, 0, -1):
				yMod -= 1
				for xMod in REGION_SIZE:
					var xPos = posStart.x + xMod
					var yPos = posStart.y + yMod
					var pos = Vector2(xPos, yPos)
					var pixelType = GetPixel(pos)
					if pixelType == PixelType.DUST:
						UpdateDustPixelSim(pos, image)
	
	image.unlock()
	sprite.get_texture().set_data(image)

func _input(event):
	if event.is_action_pressed("debug_button_1"):
		pass
	if event.is_action_pressed("spawn_pixel") or event.is_action_pressed("spawn_bulk_pixels"):
		var unscaledX = event.position.x / 2
		var unscaledY = event.position.y / 2
		var pos = Vector2(unscaledX, unscaledY)
		var simPos = GetSimPos(pos)
		var simPosX = simPos.x
		var simPosY = simPos.y
		
		if event.is_action_pressed("spawn_bulk_pixels"):
			CreateBulkDust(Vector2(simPosX, simPosY))
			CreateBulkDust(Vector2(simPosX+5, simPosY))
			CreateBulkDust(Vector2(simPosX-5, simPosY))
			CreateBulkDust(Vector2(simPosX+10, simPosY))
			CreateBulkDust(Vector2(simPosX-10, simPosY))
			CreateBulkDust(Vector2(simPosX-15, simPosY))
			CreateBulkDust(Vector2(simPosX+15, simPosY))
			CreateBulkDust(Vector2(simPosX-20, simPosY))
			CreateBulkDust(Vector2(simPosX+20, simPosY))
			CreateBulkDust(Vector2(simPosX-25, simPosY))
			CreateBulkDust(Vector2(simPosX+25, simPosY))
		else:
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
	var sweepHeight = 5
	var checkNum = 1
	var xStart = pos.x - ((sweepHeight - 1) * mod)
	var yStart = pos.y - (sweepHeight - 1)
	for y in range(yStart, yStart+sweepHeight, 1):
		var c = 1
		for x in range(xStart, xStart+(sweepHeight * mod), mod):
			if c <= checkNum:
				if GetPixel(Vector2(x, y)) == PixelType.DUST:
					var currentPos = Vector2(x, y)
					
					var dirPos = Vector2(x-mod, y)
					var dirUpPos = Vector2(x-mod, y-1)
					var dirUpUpPos = Vector2(x-mod, y-2)
					
					var dirPosInBounds = IsInBounds(dirPos)
					var dirUpPosInBounds = IsInBounds(dirUpPos)
					var dirUpUpPosInBounds = IsInBounds(dirUpUpPos)
					
					if dirPosInBounds and GetPixel(dirPos) == PixelType.EMPTY:
						MovePixel(currentPos, dirPos, image)
					elif dirUpPosInBounds and GetPixel(dirUpPos) == PixelType.EMPTY:
						MovePixel(currentPos, dirUpPos, image)
					elif dirUpUpPosInBounds and GetPixel(dirUpUpPos) == PixelType.EMPTY:
						MovePixel(currentPos, dirUpUpPos, image)
			c += 1
		checkNum += 1
	
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

func UpdateSimThreaded(delta):
	
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
	ResetRegions(checkRegionsBuffers[nextRegionsBufferNum])
	

	# One idea is to only do one region stage!!! Try this.
	# one stage covers all regions anyway I believe, then why checkerboard??
	for stageNum in simStages.size():
		#print("- SimStageNum - ", stageNum)
		#var stageStartTimeUSec = Time.get_ticks_usec()
		
		var nextThreadToFill = 0
		
		var stageRegions = simStages[stageNum]
		for regionPos in stageRegions:
			
			var regionIndex = (regionPos.y * regionWorldSizeX) + regionPos.x
			
			var regionsBuffer = checkRegionsBuffers[activeRegionsBufferNum]
			var region = regionsBuffer[regionIndex]
			
			#first check if this is active and we even need to do it
			if region.active:
				var threadNum = nextThreadToFill % THREAD_COUNT
				nextThreadToFill += 1
				var threadData = simThreadsData[threadNum]
				
				# push this region onto the work the threads need to do
				threadData.regionWorkData.push_back({
					regionPos = regionPos,
					dirtyRect = region.dirtyRect,
					image = image
				})
		
		# workData all set, now just kick threads to do the work
		for threadData in simThreadsData:
			if threadData.regionWorkData:
				threadData.idle = false
				threadData.startWorkSemaphore.post()
		
		# wait until all threads are finished before starting next stage
		var allIdle = false
		while !allIdle:
			allIdle = true
			for threadData in simThreadsData:
				allIdle = allIdle && threadData.idle
		
		#var stagesTimeMS = Global.USecToMSec(Time.get_ticks_usec() - stageStartTimeUSec)
		#print("- EndStageNum - ", stageNum, ", timeTaken:", stagesTimeMS)
	
	#var allStagesTimeTakenMS = Global.USecToMSec(Time.get_ticks_usec() - stagesStartTimeUSec)
	#print("-- simStages finished -- timeTaken: ", allStagesTimeTakenMS)
	
	image.unlock()
	sprite.get_texture().set_data(image)

# thread keeps on looping until told to stop
# allThreadData keeps the relevant info for doing work,
# the only thread data need is the threadNum to index into the allThreadData
func _thread_function(threadNum):
	
	var threadData = simThreadsData[threadNum]
	
	while !threadData.stopQueued:
		threadData.idle = true
		threadData.startWorkSemaphore.wait()
		
		while threadData.regionWorkData.size() > 0:
			#var workStartTimeUSec = Time.get_ticks_usec()
			var workData = threadData.regionWorkData.pop_back()
			
			#print("threadNum:", threadNum,  "   -   workData:", workData)
			
			var regionPos = workData.regionPos
			var dirtyRect = workData.dirtyRect
			var image = workData.image

			var regionMidPoint = Vector2()
			regionMidPoint.x = (regionPos.x * REGION_SIZE) + regionHalfSizeX
			regionMidPoint.y = (regionPos.y * REGION_SIZE) + regionHalfSizeY
			
			var startX = max(0, max(dirtyRect.minX, regionMidPoint.x - REGION_SIZE))
			var startY = max(0, max(dirtyRect.minY, regionMidPoint.y - REGION_SIZE))
			var endX = min(pixelWorldSizeX, min(dirtyRect.maxX, regionMidPoint.x + REGION_SIZE))
			var endY = min(pixelWorldSizeY, min(dirtyRect.maxY, regionMidPoint.y + REGION_SIZE))
			
			# starts at the bottom of the screen so falling pixels only update once
			var yPos = endY
			while yPos >= startY: 
				var xPos = startX
				while xPos <= endX:
					var pos = Vector2(xPos, yPos)
					var pixelType = GetPixel(pos)
					if pixelType == PixelType.DUST:
						UpdateDustPixelSim(pos, image)
					xPos += 1
				yPos -= 1
				
			#var totalMS = Global.USecToMSec(Time.get_ticks_usec() - workStartTimeUSec)
			#print("ThreadWorkEnd - threadNum:", threadNum, ", regionPos =", regionPos, ", totalMS:", totalMS, ", regionIndex: ", regionIndex, ", skipped:", str(!checkRegion))

func _physics_process(delta):
	if USE_THREAD_VERSION:
		UpdateSimThreaded(delta)
	else:
		UpdateSim(delta)
	update()

# DEBUG: DRAW REGION - uncomment _draw() and update()
#func _draw():
#	var scaledRegionSize = REGION_SIZE * pixelSizeScale
#	var regionRectSize = Vector2(scaledRegionSize, scaledRegionSize)
#
#	var regionFinalIndex = (pixelWorldSizeX / REGION_SIZE) * (pixelWorldSizeY / REGION_SIZE) - 1
#	for i in range(regionFinalIndex, -1, -1):
#		var posStart = ConvertRegionIndexToPosStart(i)
#		var scaledPos = posStart * pixelSizeScale
#		var rect = Rect2(scaledPos, regionRectSize)
#		var c = Color(0, 1, 0, 0.2)
#		if !checkRegions[i]:
#			c.g = 0
#			c.r = 1
#		draw_rect(rect, c, true)

# DEBUG: DRAW COLLISION - uncomment _draw() and update()
#func _draw():
#	var rectSize = Vector2(pixelSizeScale, pixelSizeScale)
#
#	var pixelFinalIndex = (pixelWorldSizeX * pixelWorldSizeY) - 1
#	for i in range(pixelFinalIndex, -1, -1):
#		if pixelTypes[i] == PixelType.COLLISION:
#			var x = (i % pixelWorldSizeX) * pixelSizeScale
#			var y = floor(i / pixelWorldSizeX) * pixelSizeScale
#			var pos = Vector2(x, y)
#			var rect = Rect2(pos, rectSize)
#			var c = Color(0, 1, 1, 0.9)
#			draw_rect(rect, c, true)


# Debug code by Dom, will merge sort out soon
func _draw():
	if false and USE_THREAD_VERSION:
		var regionSize = Vector2(REGION_SIZE * pixelSizeScale, REGION_SIZE * pixelSizeScale)

		var default_font = Control.new().get_font("font")

		var regionFinalIndex = (regionWorldSizeX * regionWorldSizeY) - 1
		for i in range(regionFinalIndex, -1, -1):
			var posStart = ConvertRegionIndexToPosStart(i)
			var rect = Rect2(posStart.x * pixelSizeScale, posStart.y * pixelSizeScale, regionSize.x, regionSize.y)
			var regionBuffer = checkRegionsBuffers[nextRegionsBufferNum]
			var region = regionBuffer[i]
			if region.active:
				draw_rect(rect, Color.gray, false)
				
				var dirtyRect = region.dirtyRect
				var drawDirtyRect = Rect2()
				drawDirtyRect.position.x = dirtyRect.minX * pixelSizeScale
				drawDirtyRect.position.y = dirtyRect.minY * pixelSizeScale
				drawDirtyRect.end.x = (dirtyRect.maxX + 1) * pixelSizeScale
				drawDirtyRect.end.y = (dirtyRect.maxY + 1) * pixelSizeScale
				draw_rect(drawDirtyRect, Color.yellow, false)
			else:
				draw_rect(rect, Color.black, false)

#	var stageColors = [Color.black, Color.red, Color.green, Color.blue]
#	for stageNum in simStages.size():
#		var simStage = simStages[stageNum]
#		for regionPos in simStage:
#			var regionIndex = (regionPos.y * regionWorldSizeX) + regionPos.x
#			var posStart = Vector2(regionPos.x * REGION_SIZE, regionPos.y * REGION_SIZE)
#			var rect = Rect2(posStart, Vector2(REGION_SIZE-1, REGION_SIZE-1))
#			draw_rect(rect, stageColors[stageNum % stageColors.size()], false)
#			#draw_string(default_font, Vector2(posStart.x+(REGION_SIZE/2), posStart.y+(REGION_SIZE/2)), str(stageNum))
#			#draw_string(default_font, Vector2(posStart.x+(REGION_SIZE/2), posStart.y+(REGION_SIZE/2)), str(regionIndex))
