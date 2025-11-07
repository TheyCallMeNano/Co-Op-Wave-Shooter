extends Node

var address: String
var peer: ENetMultiplayerPeer
var port: int
var level: PackedScene
var userName: String
enum ClassType { ROCKET, GRAPPLING_HOOK }
var sClass: ClassType = ClassType.ROCKET
var connectedIDs := []

var playerNodes := {}
# Store client data by peer ID
var clientData := {}

func setActiveServerInfo(conectee: ENetMultiplayerPeer, serverPort: int, scene: PackedScene, ip: String, hostUsername: String, playerClass: int) -> void:
	peer = conectee
	port = serverPort
	level = scene
	address = ip
	userName = hostUsername
	sClass = playerClass as ClassType

func getActiveServerInfo() -> Dictionary:
	return {
		"peer": peer,
		"port": port,
		"level": level,
		"address": address,
		"userName": userName,
		"sClass": sClass
	}

func multiplayerStart() -> void:
	print("Current server info is: " + str(getActiveServerInfo()))
	get_tree().change_scene_to_packed(level)
	
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	
	# Host spawns their own player locally
	spawnLocalPlayer(1, userName, sClass)
	
	multiplayer.peer_connected.connect(_onPeerConnected)
	multiplayer.peer_disconnected.connect(_onPeerDisconnected)

func _onPeerConnected(newPeerId: int) -> void:
	print("Peer " + str(newPeerId) + " connected")
	
	# Send existing players to the new client
	var names: Array[String] = []
	var classes: Array[int] = []
	for peerId: int in connectedIDs:
		if playerNodes.has(peerId):
			names.append(playerNodes[peerId].username)
			classes.append(playerNodes[peerId].classInt)
	
	rpc_id(newPeerId, "addPreviousPlayers", connectedIDs, names, classes)
	
	# Request the client's actual data
	rpc_id(newPeerId, "requestClientData")

func _onPeerDisconnected(peerId: int) -> void:
	await get_tree().create_timer(1).timeout
	if playerNodes.has(peerId):
		playerNodes[peerId].queue_free()
		playerNodes.erase(peerId)
		connectedIDs.erase(peerId)
	if clientData.has(peerId):
		clientData.erase(peerId)
	print("Player " + str(peerId) + " has disconnected")
	globals.chatLog.append("Player " + str(peerId) + " has disconnected\n")

func spawnLocalPlayer(peerId: int, playerName: String, selectedClass: ClassType) -> void:
	# Only add if not already exists
	if playerNodes.has(peerId):
		return
	
	connectedIDs.append(peerId)
	var player: Node = load("uid://dfvwlanihtgh7").instantiate()
	player.position.y = 1.5
	player.set_multiplayer_authority(peerId)
	player.name = "Player_" + str(peerId)
	if playerName == "":
		player.username = "m00tY"
	else:
		player.username = playerName
	player.classInt = selectedClass
	playerNodes[peerId] = player
	call_deferred("add_child", player)
	print("Spawned local player " + playerName + " with ID " + str(peerId) + " and authority " + str(peerId))

func addRemotePlayer(peerId: int, playerName: String, selectedClass: ClassType) -> void:
	# Only add if not already exists and not our own player
	if playerNodes.has(peerId) || peerId == multiplayer.get_unique_id():
		return
	
	connectedIDs.append(peerId)
	var player: Node = load("uid://dfvwlanihtgh7").instantiate()
	player.position.y = 1.5
	player.set_multiplayer_authority(peerId)
	player.name = "Player_" + str(peerId)
	if playerName == "":
		player.username = "m00tY"
	else:
		player.username = playerName
	player.classInt = selectedClass
	playerNodes[peerId] = player
	call_deferred("add_child", player)
	print("Added remote player " + playerName + " with ID " + str(peerId))

func handleIncoming(hostPort: int, hostIp: String, clientName: String, clientClass: int) -> void:
	# Store the client's own info
	userName = clientName
	sClass = clientClass as ClassType
	
	get_tree().change_scene_to_packed(level)
	peer.create_client(hostIp, hostPort)
	multiplayer.multiplayer_peer = peer
	
	# Connect to the connected_to_server signal
	multiplayer.connected_to_server.connect(_onConnectedToServer)

func _onConnectedToServer() -> void:
	print("Connected to server as client")
	# Spawn ourselves immediately with our own data
	spawnLocalPlayer(multiplayer.get_unique_id(), userName, sClass)

@rpc("any_peer", "reliable")
func requestClientData() -> void:
	var peerId := multiplayer.get_remote_sender_id()
	print("Server requested client data from " + str(peerId))
	# Send our actual data back to the server
	rpc_id(1, "receiveClientData", userName, sClass)

@rpc("any_peer", "reliable")
func receiveClientData(clientName: String, clientClass: ClassType) -> void:
	var peerId := multiplayer.get_remote_sender_id()
	print("Received client data from " + str(peerId) + ": " + clientName)
	
	# Store the client's actual data
	clientData[peerId] = {"name": clientName, "class": clientClass}
	
	# Now spawn the remote player with their actual data
	addRemotePlayer(peerId, clientName, clientClass)
	
	# Notify all other clients about this new player
	rpc("addNewPlayer", peerId, clientName, clientClass)
	
	globals.chatLog.append("Player " + clientName + " has connected\n")
	print("Player " + clientName + " has connected")

@rpc("reliable")
func addNewPlayer(newPeerId: int, playerName: String, selectedClass: ClassType) -> void:
	# Only add if this isn't our own player
	if newPeerId != multiplayer.get_unique_id():
		print("Adding remote player " + playerName + " with ID " + str(newPeerId))
		addRemotePlayer(newPeerId, playerName, selectedClass)

@rpc("reliable")
func addPreviousPlayers(peerIds: Array, names: Array[String], classes: Array[int]) -> void:
	print("Adding previous players: " + str(peerIds))
	for i in peerIds.size():
		var peerId: int = peerIds[i]
		# Don't add ourselves if we're in the list
		if peerId != multiplayer.get_unique_id() and i < names.size() and i < classes.size():
			print("Adding existing remote player " + names[i] + " with ID " + str(peerId))
			addRemotePlayer(peerId, names[i], classes[i] as ClassType)
