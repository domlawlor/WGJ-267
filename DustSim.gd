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

# pick pixel scale size here
#onready var sprite : Sprite = $Sprite_4x
onready var sprite : Sprite = $Sprite_2x

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

func _ready():
	sprite.visible = true
	pixelSizeScale = sprite.scale.x
	
	pixelWorldSizeX = worldSizeX / pixelSizeScale
	pixelWorldSizeY = worldSizeY / pixelSizeScale
	
	regionWorldSizeX = pixelWorldSizeX / REGION_SIZE
	regionWorldSizeY = pixelWorldSizeY / REGION_SIZE
	
	print("TextureSize-", sprite.get_texture().get_size())
	print("Image-", sprite.get_texture().get_data().get_size())
	ClearWorld()
	SetLevelCollisions()

# TODO: Pull these values from elsewhere
# TODO: also this fixes us to one screens worth of pixels. 
#		Change in future to bigger world, only updating whats close to the player


func GetPixel(pos):
	return pixelTypes[(pos.y * pixelWorldSizeX) + pos.x]

func SetPixel(pos, type):
	pixelTypes[(pos.y * pixelWorldSizeX) + pos.x] = type
	ActivateRegion(pos)

func ActivateRegion(pos):
	var regX = floor(pos.x / REGION_SIZE)
	var regY = floor(pos.y / REGION_SIZE)
	var regIndex = regY * regionWorldSizeX + regX
	checkRegions[regIndex] = true #actual pos index
	
	var regionCount = regionWorldSizeX * regionWorldSizeY
	if regIndex > 0:
		checkRegions[regIndex - 1] = true # to the left
	if regIndex < regionCount - 1:
		checkRegions[regIndex + 1] = true # to the right
	#if regIndex >= regionWorldSizeX:
		#checkRegions[regIndex - regionWorldSizeX] = true # to the up
	if regIndex < regionCount - regionWorldSizeX:
		checkRegions[regIndex + regionWorldSizeX] = true # to the down

func ClearWorld():
	var pixelCount = pixelWorldSizeX * pixelWorldSizeY
	pixelTypes.resize(pixelCount)
	pixelTypes.fill(PixelType.EMPTY)
	
	var regionCount = regionWorldSizeX * regionWorldSizeY
	checkRegions.resize(regionCount)
	checkRegions.fill(true)
	
	var image = sprite.get_texture().get_data()
	image.lock()
	image.fill(Color.transparent)
	image.unlock()
	sprite.get_texture().set_data(image)

func SetLevelCollisions():
	for i in range(0, pixelTypes.size()):
		colTest.position.x = (i % pixelWorldSizeX) * pixelSizeScale
		colTest.position.y = floor(i / pixelWorldSizeX) * pixelSizeScale
		var col = colTest.move_and_collide(Vector2.ZERO, true, true, true)
		if col != null:
			pixelTypes[i] = PixelType.COLLISION

func CreateDust(positions):
	var image = sprite.get_texture().get_data()
	image.lock()
	
	for pos in positions:
		if !IsInBounds(pos) or !IsPixelFree(pos):
			continue
		
		print("CreateDust xPos:", pos.x, ", yPos:", pos.y)
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
		image.set_pixel(pos.x, pos.y, color)
	
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
	var randNum = randi() % 2
	
	var downPos = Vector2(pos.x, pos.y + 1)
	var downRightPos = Vector2(pos.x + 1, pos.y + 1)
	var downLeftPos = Vector2(pos.x - 1, pos.y + 1)
	
	var downPosInBounds = IsInBounds(downPos)
	var downRightPosInBounds = IsInBounds(downRightPos)
	var downLeftPosInBounds = IsInBounds(downLeftPos)
	
	if downPosInBounds and GetPixel(downPos) == PixelType.EMPTY:
		MovePixel(pos, downPos, image)
		return true
	elif downRightPosInBounds and GetPixel(downRightPos) == PixelType.EMPTY:
		MovePixel(pos, downRightPos, image)
		return true
	elif downLeftPosInBounds and GetPixel(downLeftPos) == PixelType.EMPTY:
		MovePixel(pos, downLeftPos, image)
		return true
	return false

# One idea is we could get rid of delta by running in fixed time steps
#	So in sim, accumulate the delta and once bigger than a fixedTimeStep, run the sim.
func UpdateSim(delta):
	
	var image = sprite.get_texture().get_data()
	image.lock()
	var regionFinalIndex = (regionWorldSizeX * regionWorldSizeY) - 1
	for i in range(regionFinalIndex, -1, -1):
		var checkRegionNextFrame = false
		if checkRegions[i]:
			var posStart = ConvertRegionIndexToPosStart(i)
			for yMod in range(REGION_SIZE, 0, -1):
				yMod -= 1
				for xMod in REGION_SIZE:
					var xPos = posStart.x + xMod
					var yPos = posStart.y + yMod
					var pos = Vector2(xPos, yPos)
					var pixelType = GetPixel(pos)
					if pixelType == PixelType.DUST:
						checkRegionNextFrame = UpdateDustPixelSim(pos, image)
			if checkRegionNextFrame:
				ActivateRegion(posStart)
			else:
				checkRegions[i] = false
	
	image.unlock()
	sprite.get_texture().set_data(image)

func _input(event):
	if event.is_action_pressed("debug_button_1"):
		pass
	if event.is_action_pressed("spawn_pixel") or event.is_action_pressed("spawn_bulk_pixels"):
		var simPosX = floor(event.position.x / pixelSizeScale)
		var simPosY = floor(event.position.y / pixelSizeScale)
		var simPos = Vector2(simPosX, simPosY)
		print(simPos)
		
		if event.is_action_pressed("spawn_bulk_pixels"):
			CreateBulkDust(Vector2(simPosX, simPosY))
			CreateBulkDust(Vector2(simPosX+5, simPosY))
			CreateBulkDust(Vector2(simPosX-5, simPosY))
			CreateBulkDust(Vector2(simPosX+10, simPosY))
			CreateBulkDust(Vector2(simPosX-10, simPosY))
		else:
			CreateDust([simPos])
		
func ConvertRegionIndexToPosStart(rIndex):
	var x = (rIndex % regionWorldSizeX) * REGION_SIZE
	var y = floor(rIndex / regionWorldSizeX) * REGION_SIZE
	return Vector2(x, y)

func _physics_process(delta):
	UpdateSim(delta)
	#update()

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
