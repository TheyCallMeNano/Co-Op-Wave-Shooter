extends Node3D

@onready var enemy = preload("res://Objects/objEnemyGeneric.tscn")

@onready var children = get_children()
@onready var childrenAmt = get_child_count()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if globals.waveNum == 0 && globals.waveNumMax == 0:
		var spawnAmt = randi_range(1, 10)
		startNewWave(spawnAmt)
		globals.waveNumMax = spawnAmt
		globals.waveNum = 1
		globals.eAlive = spawnAmt
		globals.eMax = spawnAmt

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if globals.eAlive == 0 && globals.waveNum != globals.waveNumMax:
		globals.waveNum += 1
		var spawnAmt = randi_range(1, 10)
		startNewWave(spawnAmt)

func startNewWave(amt):
		var spawn_points = get_children()  # Get all children nodes.
		# Shuffle the spawn points to randomize where enemies will spawn from
		spawn_points.shuffle()
		# Limit the spawn amount to the number of available spawn points
		var actual_spawn_amt = min(amt, spawn_points.size())
		var used_indices = []
		for i in range(actual_spawn_amt):

			var enemyInst = enemy.instantiate()
			var spawn_index = randi() % spawn_points.size()  # Get a random index from spawn_points
			
			# Ensure we don't use the same spawn point for multiple enemies
			while used_indices.has(spawn_index):
				spawn_index = randi() % spawn_points.size()
			
			used_indices.append(spawn_index)
			var spawn_position = spawn_points[spawn_index].position  # Use random spawn points
			# Debug: Log the position where the enemy will spawn
			enemyInst.position = spawn_position
			globals.eAlive += 1
			call_deferred("add_child", enemyInst)
