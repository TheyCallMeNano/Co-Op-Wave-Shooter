extends Node3D

@onready var enemy := preload("res://Objects/objEnemyGeneric.tscn")
@onready var paths := $"../Paths".get_children()

@onready var children := get_children()
@onready var childrenAmt := get_child_count()
var aliveEnemies : Array

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
			MultiplayerManager.setWaveInfo(globals.waveNum, globals.waveNumMax, globals.eAlive, globals.eMax)
	else:
		var waveInfo := MultiplayerManager.getWaveInfo()
		await get_tree().create_timer(0.1).timeout
		waveInfo = MultiplayerManager.getWaveInfo()
		globals.waveNum = waveInfo["curWave"]
		globals.waveNumMax = waveInfo["maxWaves"]
		globals.eAlive = waveInfo["enemyAmount"]
		globals.eMax = waveInfo["maxEnemyAmount"]
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if globals.eAlive == 0 && globals.waveNum != globals.waveNumMax && is_multiplayer_authority():
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
	MultiplayerManager.setWaveInfo(globals.waveNum, globals.waveNumMax, globals.eAlive, globals.eMax)
	rpc("updateWaveInfo", MultiplayerManager.getWaveInfo())

@rpc()
func updateWaveInfo(waveInfo: Dictionary) -> void:
		globals.waveNum = waveInfo["curWave"]
		globals.eAlive = waveInfo["enemyAmount"]
		globals.eMax = waveInfo["maxEnemyAmount"]
