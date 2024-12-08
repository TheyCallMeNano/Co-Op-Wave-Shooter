extends CharacterBody3D

# Imports
@onready var NavAgent : NavigationAgent3D = $NavigationAgent3D
@onready var timer : Timer = $Timer

@export var hp: int = 100

# Movement
@export_category("Movement")
var projectedSpeed: float
@export var jumpVelocity := 4.5
@export var friction := 6.0
@export var accel := 5.0
@export var accelAir := 40.0
@export var groundedMax := 15.0
@export var airMax := 2.5
@export var linearFriction := 10.0
var grounded := true
var prevGrounded := true
var wishDir := Vector3.ZERO

var checkpoints := []
var pathProgress := 0

var stuckCounter := 0
var finalDest := Vector3.ZERO

var plrBody : Object = null
var spawnPos: Vector3 = Vector3.ZERO

func _ready() -> void:
	var randomPosition := Vector3(randf_range(-500.0, 500.0), 0, randf_range(-500.0, 500.0))
	NavAgent.set_target_position(checkpoints[0].global_position)
	spawnPos = global_position

func _physics_process(delta: float) -> void:
	var final_position := NavAgent.get_final_position()
	
	# Check if the agent has reached the final position within a small threshold distance
	if plrBody == null && global_position.distance_to(final_position) < 2.0:
		if pathProgress != checkpoints.size() - 1:
			pathProgress += 1
			NavAgent.set_target_position(checkpoints[pathProgress].global_position)
		timer.start(10)
	elif plrBody != null:
		timer.stop()
		stuckCounter = 0
		NavAgent.set_target_position(plrBody.global_position)
	
	# Update the destination and calculate movement direction
	var destination := NavAgent.get_next_path_position()
	var localDestination := destination - global_position
	var inputDir := localDestination.normalized() #(0.2,0,0.75)
	
	# Set the movement direction for the agent
	wishDir = Vector3(inputDir.x, 0, inputDir.z)
	projectedSpeed = (velocity * Vector3(1, 0, 1)).dot(wishDir)
	
	# Handle ground and air movement
	if !is_on_floor():
		grounded = false
		airMove(delta)
	else:
		if velocity.y > 10:
			grounded = false
			airMove(delta)
		else:
			grounded = true
			groundMove(delta)
	
	# Move the character using move_and_slide()
	move_and_slide()


func _process(delta: float) -> void:
	if hp <= 0:
		globals.eAlive -= 1
		queue_free()

func applyFriction(delta: float) -> void:
	var speedScalar := 0.0
	var frictionCurve := 0.0
	var speedLoss := 0.0
	var curSpd := 0.0
	
	curSpd = velocity.length()
	
	if (curSpd < 0.1):
		velocity.x = 0
		velocity.y = 0
		return
	
	frictionCurve = clampf(curSpd, linearFriction, INF)
	speedLoss = frictionCurve * friction * delta
	speedScalar = clampf(curSpd - speedLoss, 0, INF)
	speedScalar /= clampf(curSpd, 1, INF)
	
	velocity *= speedScalar

func applyAccel(acceleration: float, topSpd: float, delta: float) -> void:
	var speedLeft := 0.0
	var accelFinal := 0.0
	
	speedLeft = (topSpd * wishDir.length()) - projectedSpeed
	
	if speedLeft <= 0:
		return
	
	accelFinal = acceleration * delta * topSpd
	
	clampf(accelFinal, 0, speedLeft)
	
	velocity.x += accelFinal * wishDir.x
	velocity.z += accelFinal * wishDir.z

func airMove(delta: float) -> void:
	applyAccel(accelAir, airMax, delta)
	
	clipVelocity(get_wall_normal(), 14, delta)
	clipVelocity(get_floor_normal(), 14, delta)
	
	# Include downward gravity acceleration
	velocity.y -= globals.gravity * delta

	# Check if we are on a downward slope and adjust movement accordingly
	if is_on_floor() && get_floor_normal().y < 0:
		velocity.y = max(velocity.y, 0)  # Prevent bouncing off downward slopes

func groundMove(delta: float) -> void:
	applyAccel(accel, groundedMax, delta)
	
	if grounded == prevGrounded:
		applyFriction(delta)
	
	if is_on_wall():
		clipVelocity(get_wall_normal(), 1, delta)
	
	# Check if the character is stuck on a downward slope
	if is_on_floor() && get_floor_normal().y < 0:
		# Allow slight downward velocity to move the agent
		velocity.y = max(velocity.y, -2)  # Adjust this value as needed


@warning_ignore("unused_parameter")
func clipVelocity(normal: Vector3, overBounce: float, delta: float) -> void:
	var correctionAmt := 0.0
	var correctionDir := Vector3.ZERO
	var moveDir : Vector3 = get_velocity().normalized()
	
	correctionAmt = moveDir.dot(normal) * overBounce
	
	correctionDir = normal * correctionAmt
	velocity -= correctionDir
	# Below works well if on high globals.gravity
	velocity.y -= correctionDir.y * (globals.gravity/20)

func _on_sightline_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		plrBody = body


func _on_sightline_body_exited(body: Node3D) -> void:
	if body == plrBody:
		plrBody = null


func _on_timer_timeout() -> void:
	var next_checkpoint := NavAgent.get_next_path_position()
	#print("Distance to next checkpoint: ", global_position.distance_to(next_checkpoint))
	#stuckCounter += 1
	#if stuckCounter < 5:
		#velocity.y = jumpVelocity
		#timer.start(1)
	#elif stuckCounter == 5:
		#NavAgent.set_target_position(spawnPos)
		#timer.start(5)
	#elif stuckCounter > 5:
		#global_position = spawnPos
		#stuckCounter = 0


func _on_sightline_area_entered(area: Area3D) -> void:
	if area.name == "OnionRing":
		global_position = spawnPos
		pathProgress = 0
		NavAgent.set_target_position(checkpoints[0].global_position)
		globals.objHP -= 1
