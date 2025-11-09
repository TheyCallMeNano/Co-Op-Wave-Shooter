extends Node3D

@onready var enemy := preload("res://Objects/objEnemyGeneric.tscn")
@onready var paths := $"../Paths".get_children()

@onready var children := get_children()
@onready var childrenAmt := get_child_count()
var aliveEnemies : Array

# URGENT: 2 options for wave syncing force players to reset and start waves themelves
# or use the synced info upon update to get updated spawns
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if is_multiplayer_authority():
		if globals.waveNum == 0 && globals.waveNumMax == 0:
			var spawnAmt := randi_range(1, 10)
			startNewWave(spawnAmt)
			globals.waveNumMax = spawnAmt
			globals.waveNum = 1
			globals.eAlive = spawnAmt
			globals.eMax = spawnAmt
			await get_tree().process_frame
			MultiplayerManager.setWaveInfo(globals.waveNum, globals.waveNumMax, aliveEnemies, globals.eAlive, globals.eMax)
	else:
		var waveInfo := MultiplayerManager.getWaveInfo()
		if waveInfo["livingEnemies"].size() == 0:
			await get_tree().create_timer(0.1).timeout
			waveInfo = MultiplayerManager.getWaveInfo()
			globals.waveNum = waveInfo["curWave"]
			globals.waveNumMax = waveInfo["maxWaves"]
			globals.eAlive = waveInfo["enemyAmount"]
			globals.eMax = waveInfo["maxEnemyAmount"]
		
		#for enemyData: Dictionary in waveInfo["livingEnemies"]:
			#var enemyInst := enemy.instantiate()
			#enemyInst.name = enemyData["name"]
			#enemyInst.position = enemyData["position"]
			#enemyInst.rotation = enemyData["rotation"]
			#
			#var path_choice := "../Paths/Path" + str(enemyData["path_index"])
			#var path_node := get_node(path_choice)
			#enemyInst.checkpoints = path_node.get_children()
			#
			#enemyInst.set_multiplayer_authority(1)  # Server has authority
			#add_child(enemyInst)

# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if globals.eAlive == 0 && globals.waveNum != globals.waveNumMax:
		globals.waveNum += 1
		var spawnAmt := randi_range(1, 10)
		startNewWave(spawnAmt)
		

func startNewWave(amt: int) -> void:
	if !is_multiplayer_authority():
		return
	var spawn_points := get_children()  # Get all children nodes.
	# Shuffle the spawn points to randomize where enemies will spawn from
	spawn_points.shuffle()
	# Limit the spawn amount to the number of available spawn points
	var actual_spawn_amt : int = min(amt, spawn_points.size())
	var used_indices := []
	for i in range(actual_spawn_amt):
		
		# Generate a random index for the path
		var random_index := randi_range(1, paths.size())
		
		# Construct the path as a string
		var path_choice := "../Paths/Path" + str(random_index)
		print(path_choice)
		
		# Access the node using get_node()
		var path_node := get_node(path_choice)
		var pathChildren := path_node.get_children()
		print(pathChildren)
		
		var enemyInst := enemy.instantiate()
		var spawn_index := randi() % spawn_points.size()  # Get a random index from spawn_points
		
		# Ensure we don't use the same spawn point for multiple enemies
		while used_indices.has(spawn_index):
			spawn_index = randi() % spawn_points.size()
		
		used_indices.append(spawn_index)
		var spawn_position : Vector3 = spawn_points[spawn_index].position  # Use random spawn points
		# Debug: Log the position where the enemy will spawn
		enemyInst.position = spawn_position
		enemyInst.name = "Enemy_" + str(i)
		enemyInst.checkpoints = pathChildren
		enemyInst.set_meta("path_index", random_index)  # Store the path index
		enemyInst.set_multiplayer_authority(1)
		globals.eAlive += 1
		call_deferred("add_child", enemyInst)
	
	# Wait for all enemies to be added before collecting them
	call_deferred("_collect_alive_enemies")

func _collect_alive_enemies() -> void:
	aliveEnemies.clear()  # Clear the array first
	for child: Node in get_children():
		if child.is_in_group("enemies"):
			aliveEnemies.append(child)
	MultiplayerManager.setWaveInfo(globals.waveNum, globals.waveNumMax, aliveEnemies, globals.eAlive, globals.eMax)
	print(str(MultiplayerManager.getWaveInfo()))
