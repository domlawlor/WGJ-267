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
var pixelWorldSizeX = 160
var pixelWorldSizeY = 120
var pixelTypes = []

func GetPixel(pos):
	return pixelTypes[(pos.y * pixelWorldSizeX) + pos.x]

func SetPixel(pos, type):
	pixelTypes[(pos.y * pixelWorldSizeX) + pos.x] = type

func ClearWorld():
	var pixelCount = pixelWorldSizeX * pixelWorldSizeY
	pixelTypes.resize(pixelCount)
	pixelTypes.fill(PixelType.EMPTY)
	
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

func UpdateDustPixelSim(pos, velocity, image):
	var randNum = randi() % 2
	
	var downPos = Vector2(pos.x, pos.y + velocity)
	var downRightPos = Vector2(pos.x + velocity, pos.y + velocity)
	var downLeftPos = Vector2(pos.x - velocity, pos.y + velocity)
	
	var downPosInBounds = IsInBounds(downPos)
	var downRightPosInBounds = IsInBounds(downRightPos)
	var downLeftPosInBounds = IsInBounds(downLeftPos)
	
	if downPosInBounds and GetPixel(downPos) == PixelType.EMPTY:
		MovePixel(pos, downPos, image)
	elif downRightPosInBounds and GetPixel(downRightPos) == PixelType.EMPTY:
		MovePixel(pos, downRightPos, image)
	elif downLeftPosInBounds and GetPixel(downLeftPos) == PixelType.EMPTY:
		MovePixel(pos, downLeftPos, image)

# One idea is we could get rid of delta by running in fixed time steps
#	So in sim, accumulate the delta and once bigger than a fixedTimeStep, run the sim.
func UpdateSim(delta):
	
	var image = get_texture().get_data()
	image.lock()
	
	# starts at the bottom of the screen so falling pixels only update once
	var yPos = pixelWorldSizeY - 1 # top screen is 0, bottom is worldSize.y - 1
	while yPos >= 0: 
		for xPos in range(pixelWorldSizeX): # and just increment for x, simpler
			var pos = Vector2(xPos, yPos)
			var pixelType = GetPixel(pos)
			
			if pixelType == PixelType.DUST:
				var velocity = 2
				while velocity > 0:
					UpdateDustPixelSim(pos, velocity, image)
					velocity -= 1
		yPos -= 1
	
	
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
		else:
			CreateDust([simPos])
		
		
		

func _process(delta):
	UpdateSim(delta)
	
	#var dustImage := Image.new()
	#var dustTexture := ImageTexture.new()
	
	var useMipmaps = false
	#dustImage.lock()
	#dustImage.create_from_data(worldSize.x, worldSize.y, useMipmaps, FORMAT_RGBA8, pixelColors)
	#dustImage.unlock()
	
	
	#dustTexture.create_from_image(dustImage)
	#set_texture(dustTexture)
