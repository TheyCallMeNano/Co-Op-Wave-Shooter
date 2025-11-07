
extends Control

@onready var rocket_button: Button = $Panel/VBoxContainer/Rocket_Launcher
@onready var grapple_button: Button = $Panel/VBoxContainer/Grapple_Gun

signal class_selected(new_class: int)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	rocket_button.pressed.connect(on_rocket_pressed)
	grapple_button.pressed.connect(on_grapple_pressed)
	hide()

func on_rocket_pressed() -> void:
	emit_signal("class_selected", 0)

func on_grapple_pressed() -> void:
	emit_signal("class_selected", 1)
