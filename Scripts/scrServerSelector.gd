extends Control

@onready var peer := ENetMultiplayerPeer.new()
@export var playerScene: PackedScene
var port := 1364
var address := "localhost"
@export var level : PackedScene

func _on_host_pressed() -> void:
	MultiplayerManager.setActiveServerInfo(peer, port, level, address, $Menu/Namefield.text, $Menu/OptionButton.selected)
	MultiplayerManager.multiplayerStart()

func _on_join_pressed() -> void:
	if $Menu/Port.text != "" && $"Menu/IP Adderess".text != "":
		port = $Menu/Port.text.to_int()
		address = $"Menu/IP Adderess".text
		MultiplayerManager.setActiveServerInfo(peer, port, level, address, $Menu/Namefield.text, $Menu/OptionButton.selected)
		MultiplayerManager.handleIncoming(port, address, $Menu/Namefield.text, $Menu/OptionButton.selected)
