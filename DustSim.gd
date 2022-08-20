extends Sprite

export(Color) var dustColourA
export(Color) var dustColourB
export(Color) var dustColourC
export(Color) var dustColourD

enum PixelType {
	EMPTY
	DUST
}

var worldSizeX = 640
var worldSizeY = 480

var pixelSizeScale = 4

# TODO: Pull these values from elsewhere
# TODO: also this fixes us to one screens worth of pixels. 
#		Change in future to bigger world, only updating whats close to the player
var pixelWorldSizeX = worldSizeX / pixelSizeScale
var pixelWorldSizeY = worldSizeY / pixelSizeScale
var pixelTypes = []

var REGION_SIZE = 8
var regionWorldSizeX = pixelWorldSizeX / REGION_SIZE
var regionWorldSizeY = pixelWorldSizeY / REGION_SIZE
var checkRegions = []

func GetPixel(pos):
	return pixelTypes[(pos.y * pixelWorldSizeX) + pos.x]

func SetPixel(pos, type):
	pixelTypes[(pos.y * pixelWorldSizeX) + pos.x] = type
	ActivateRegion(pos)

func ActivateRegion(pos):
	var regX = floor(pos.x / REGION_SIZE)
	var regY = floor(pos.y / REGION_SIZE)
	var regIndex = regY * regionWorldSizeX + regX
	checkRegions[regIndex] = true

func ClearWorld():
	var pixelCount = pixelWorldSizeX * pixelWorldSizeY
	pixelTypes.resize(pixelCount)
	pixelTypes.fill(PixelType.EMPTY)
	
	var regionCount = regionWorldSizeX * regionWorldSizeY
	checkRegions.resize(regionCount)
	checkRegions.fill(true)
	
	var image = get_texture().get_data()
	image.lock()
	image.fill(Color.transparent)
	image.unlock()
	get_texture().set_data(image)

func _ready():
	print("TextureSize-",get_texture().get_size())
	print("Image-",get_texture().get_data().get_size())

	ClearWorld()

func CreateDust(positions):
	var image = get_texture().get_data()
	image.lock()
	
	for pos in positions:
		if !IsInBounds(pos):
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
	get_texture().set_data(image)

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
	
	var image = get_texture().get_data()
	image.lock()
	var regionFinalIndex = (regionWorldSizeX * regionWorldSizeY) - 1
	for i in range(regionFinalIndex, -1, -1):
		var checkRegionNextFrame = false
		if checkRegions[i]:
			var posStart = ConvertRegionIndexToPosStart(i)
			for yMod in range(7, -1, -1):
				for xMod in 8:
					var xPos = posStart.x + xMod
					var yPos = posStart.y + yMod
					var pos = Vector2(xPos, yPos)
					var pixelType = GetPixel(pos)
					if pixelType == PixelType.DUST:
						checkRegionNextFrame = UpdateDustPixelSim(pos, image)
		checkRegions[i] = checkRegionNextFrame
	
	
	image.unlock()
	get_texture().set_data(image)

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
		
		
		

func _physics_process(delta):
	UpdateSim(delta)
	
	#var dustImage := Image.new()
	#var dustTexture := ImageTexture.new()
	
	var useMipmaps = false
	#dustImage.lock()
	#dustImage.create_from_data(worldSize.x, worldSize.y, useMipmaps, FORMAT_RGBA8, pixelColors)
	#dustImage.unlock()
	
	
	#dustTexture.create_from_image(dustImage)
	#set_texture(dustTexture)
	
func ConvertRegionIndexToPosStart(rIndex):
	var x = (rIndex % regionWorldSizeX) * REGION_SIZE
	var y = floor(rIndex / regionWorldSizeX) * REGION_SIZE
	return Vector2(x, y)

#func _draw():
#	var regionSize = Vector2(8, 8)
#
#	var regionFinalIndex = (pixelWorldSizeX / REGION_SIZE) * (pixelWorldSizeY / REGION_SIZE) - 1
#	for i in range(regionFinalIndex, -1, -1):
#		var posStart = ConvertRegionIndexToPosStart(i)
#		var rect = Rect2(posStart, regionSize)
#		if checkRegions[i]:	
#			draw_rect(rect, Color.green, true)
#		else:
#			draw_rect(rect, Color.red, true)
#
#	var rectSize = Vector2(1, 1)
#
#	var yPos = pixelWorldSizeY - 1 # top screen is 0, bottom is worldSize.y - 1
#	while yPos >= 0: 
#		for xPos in range(pixelWorldSizeX): # and just increment for x, simpler
#			var pos = Vector2(xPos, yPos)
#			var pixelType = GetPixel(pos)
#			if pixelType == PixelType.DUST:
#				var rect = Rect2(pos, rectSize)
#				draw_rect(rect, Color.black, true)
#		yPos -= 1
