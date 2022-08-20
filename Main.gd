extends Control

onready var menu : Control = $Menu
onready var levelList : VBoxContainer = $Menu/LevelList
onready var main_2d : Node2D = $Main2D

var level_instance : Node2D

func unload_level():
	if (is_instance_valid(level_instance)):
		level_instance.queue_free()
	level_instance = null

func load_level(level_name : String):
	unload_level()
	var level_path := "res://Levels/%s.tscn" % level_name
	var level_resource := load(level_path)
	if (level_resource):
		level_instance = level_resource.instance()
		main_2d.add_child(level_instance)
		levelList.visible = false

func _on_LoadLevel1_pressed():
	load_level("Level1")
