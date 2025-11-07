extends Node3D

@onready var peer := ENetMultiplayerPeer.new()
@export var playerScene: PackedScene
var port := 135
var address := "localhost"

var player_nodes := {}  # Store a mapping between peerID and player nodes

func _ready() -> void:
	for arg in OS.get_cmdline_args():
		if arg.contains("--server"):
			$Control/Menu.visible = false
			peer.create_server(port)
			multiplayer.multiplayer_peer = peer
			addPlayer(1)
			
			multiplayer.peer_connected.connect(
				func(newPeerID: int) -> void:
					rpc_id(newPeerID, "addPreviousPlayers", globals.connectedIDs)
					rpc("addNewPlayer", newPeerID)
					addPlayer(newPeerID)
					globals.chatLog.append("Player " + $Control/Menu/Namefield.text + " has connected\n")
					print("Player " + $Control/Menu/Namefield.text + " has connected")
			)
			
			peer.peer_disconnected.connect(
				func(peerID: int) -> void:
					await get_tree().create_timer(1).timeout
					if player_nodes.has(peerID):
						player_nodes[peerID].queue_free()  # Free the player node by peerID reference
						player_nodes.erase(peerID)  # Remove the player node reference
					print("Player " + str(peerID) + " has disconnected")
					globals.chatLog.append("Player " + str(peerID) + " has disconnected\n")
			)

func addPlayer(peerID: int) -> void:
	globals.connectedIDs.append(peerID)
	var player := playerScene.instantiate()
	player.position.y = 1.5
	player.set_multiplayer_authority(peerID)
	player.name = "Player_" + str(peerID)  # Set consistent node names
	if $Control/Menu/Namefield.text == "":
		player.username = "m00tY"
	else:
		player.username = $Control/Menu/Namefield.text
	player.classInt = $Control/Menu/OptionButton.get_selected_id()
	player_nodes[peerID] = player  # Map the peerID to the player node
	call_deferred("add_child", player)

@rpc
func addNewPlayer(newPeerID: int) -> void:
	if newPeerID != 2:
		addPlayer(newPeerID)

@rpc
func addPreviousPlayers(peerIDs: Array) -> void:
	for peerID: int in peerIDs:
		addPlayer(peerID)

func _on_host_pressed() -> void:
	$Control/Menu.visible = false
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	addPlayer(1)
	
	peer.peer_connected.connect(
		func(newPeerID: int) -> void:
			rpc_id(newPeerID, "addPreviousPlayers", globals.connectedIDs)
			rpc("addNewPlayer", newPeerID)
			addPlayer(newPeerID)
			globals.chatLog.append("Player " + $Control/Menu/Namefield.text + " has connected\n")
			print("Player " + $Control/Menu/Namefield.text + " has connected")
	)
	
	peer.peer_disconnected.connect(
		func(peerID: int) -> void:
			await get_tree().create_timer(1).timeout
			if player_nodes.has(peerID):
				player_nodes[peerID].queue_free()  # Free the player node by peerID reference
				player_nodes.erase(peerID)  # Remove the player node reference
			print("Player " + str(peerID) + " has disconnected")
			globals.chatLog.append("Player " + str(peerID) + " has disconnected\n")
	)

func _on_join_pressed() -> void:
	$Control/Menu.visible = false
	if $Control/Menu/Port.text != "" && $"Control/Menu/IP Adderess".text != "":
		port = $Control/Menu/Port.text.to_int()
		address = $"Control/Menu/IP Adderess".text
	peer.create_client(address, port)
	multiplayer.multiplayer_peer = peer
