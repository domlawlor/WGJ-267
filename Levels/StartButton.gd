extends Button

var m_active = true

func _unhandled_input(event):
	if m_active and event.is_action_pressed("button_ui_confirm"):
		StartGame()

func _on_StartButton_pressed():
	StartGame()
	
func MakeActive():
	self.visible = true
	m_active = true

func MakeInactive():
	self.visible = false
	m_active = false

func StartGame():
	MakeInactive()
	Events.emit_signal("start_game")
