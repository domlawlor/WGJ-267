extends AudioStreamPlayer

const SILENT_DB = -80
const MIN_DB = -40
const MAX_DB = -12
const INCREASE_DB = 3
const DECAY = 6

func _ready():
	Events.connect("dust_amount_changed", self, "_on_dust_amount_changed")
	self.volume_db = SILENT_DB
	self.play()

func _process(delta):
	self.volume_db = max(SILENT_DB, self.volume_db - (DECAY * delta))

func _on_dust_amount_changed(amount):
	if amount < 0:
		self.volume_db = max(min(MAX_DB, self.volume_db + INCREASE_DB), MIN_DB)
