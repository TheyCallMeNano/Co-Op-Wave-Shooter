extends CharacterBody3D

# Imports
@onready var ball := preload("res://Objects/objBall.tscn")
@onready var camera := $Head/Camera3D
@onready var head := $Head
@onready var rocket := preload("res://Objects/objRocket.tscn")
@onready var ray := $Head/Camera3D/RayCast3D
@onready var inputBox := $InfoCorner/InputBox
@onready var UIAudio := $AudioStreamPlayer2D
@onready var enemy := preload("res://Objects/objEnemyGeneric.tscn")
@onready var timer := $markerTimer
@onready var hitMarker := $Crosshair/Hitmarker
@onready var infoCorner := $InfoCorner
@onready var crosshair := $Crosshair
@onready var weaponMenuScene := preload("res://UI Elements/weaponMenu.tscn")

# Consts
const BOB_FREQ = 2.0
const BOB_AMP = 0.08

# Movement
@export_category("Movement")
var projectedSpeed: float
@export var jumpVelocity := 4.5
@export var restLength := 2.0
@export var stiffness := 1.0
@export var dmp := 1.0
@export var lookAroundSpeed := 0.005
@export var push := 5.0 
@export var friction := 6.0
@export var accel := 5.0
@export var accelAir := 40.0
@export var groundedMax := 15.0
@export var airMax := 2.5
@export var linearFriction := 10.0
@export var autoBhop := true
var grounded := true
var prevGrounded := true
var wishDir := Vector3.ZERO

# Gameplay
@export_category("Gameplay")
@export var critBucketMin := 0
@export var critBucketMax := 1000
var critBucketCur := 0

# Settings
@export_category("Settings")
# Cannot export username as it is set by a different script
var username := ""
@export_enum("Center", "Right") var viewmodel: int
@export var rocketForce := 10.0
@export var rocketSpeed := 60.0
@export var rocketRadius: = Vector3(1,1,1)

# Utility
var start_time: int = 0
var elapsed_time: int = 0
var speedrunning: int = 0
var chatArray := []
enum ClassType { ROCKET, GRAPPLING_HOOK }
var classInt: ClassType = ClassType.ROCKET
var chatting := false
var tBob := 0.0
var isServer := false
var weapon : Object
var weaponMenu : Control = null
var is_menu_open: bool
var currentWeapon: String
var weaponInst : Node = null
var animPlayer : AnimationPlayer = null
var grappleGun : MeshInstance3D = null
var grappling := false
var grapplePoint : Vector3
var commandDictionary := {
	"jumpVelocity": func(val: String) -> void:
		var value := val.to_float() 
		jumpVelocity = value,
	"push": func(val: String) -> void:
		var value := val.to_float()
		push = value,
	"gravity": func(val: String) -> void:
		var value := val.to_float()
		PhysicsServer3D.area_set_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, value)
		globals.gravity = value,
	"respawn": func(_val: String) -> void:
		velocity = Vector3.ZERO
		global_position = Vector3(0,3,0),
	"spawn": func(val: String) -> void:
		var spawnables := {"ball": ball, "rocket": rocket, "enemy": enemy}
		for i : String in spawnables.keys():
			if val.begins_with(i):
				var itm := val.erase(0, i.length()+1)
				var amnt := itm.to_int()
				globals.chatLog.append("Spawning in " + str(amnt) + " " + val + "\n")
				
				for j in amnt:
					handleSpawning(i)
					rpc("spawnRemote", i),
	"accel": func(val: String) -> void:
		var value := val.to_float()
		accel = value,
	"accelAir": func(val: String) -> void:
		var value := val.to_float()
		accelAir = value,
	"viewmodel": func(val: String) -> void:
		if val == "Right" || val == "right":
			globals.chatLog.append("Set Viewmodel to: Right for " + username + "\n")
			rpc("syncChat", "Set Viewmodel to: Right for " + username + "\n")
			$Head/Camera3D/RocketVM.position = Vector3(0.46, -1, -0.6)
		elif val == "Center" || val == "center":
			globals.chatLog.append("Set Viewmodel to: Center for " + username + "\n")
			rpc("syncChat", "Set Viewmodel to: Center for " + username + "\n")
			$Head/Camera3D/RocketVM.position = Vector3(0, -1, -0.6),
	"speedrunning": func(val: String) -> void:
		var value := val.to_int()
		if value == 1:
			globals.chatLog.append("Started speedrunning for " + username + "\n")
			rpc("syncChat", "Started speedrunning for " + username + "\n")
			start_stopwatch()
		else:
			globals.chatLog.append("Stoped speedrunning for " + username + "\n")
			rpc("syncChat", "Stoped speedrunning for " + username + "\n")
			stop_stopwatch(),
	"rocketForce": func(val: String) -> void:
		globals.chatLog.append("Set Rocket Force to: " + val + " for " + username + "\n")
		rpc("syncChat", "Set Rocket Force to: " + val + " for " + username + "\n")
		var value := val.to_float()
		rocketForce = value,
	"rocketSpeed": func(val: String) -> void:
		globals.chatLog.append("Set Rocket Speed to: " + val + " for " + username + "\n")
		rpc("syncChat", "Set Rocket Speed to: " + val + " for " + username + "\n")
		var value := val.to_float()
		rocketSpeed = value,
	"rocketRadius": func(val: String) -> void:
		globals.chatLog.append("Set Rocket Radius to: " + val + " for " + username + "\n")
		rpc("syncChat", "Set Rocket Radius to: " + val + " for " + username + "\n")
		var value := val.to_float()
		rocketRadius = Vector3(value, value, value)
}

func _ready() -> void:
	for arg in OS.get_cmdline_args():
		if arg.contains("--server"):
			isServer = true
	weaponMenu = weaponMenuScene.instantiate()
	get_tree().root.add_child(weaponMenu)
	weaponMenu.hide()
	weaponMenu.connect("class_selected", Callable(self, "_on_weapon_menu_selected"))
	$Head/Nametag.text = username
	
	if is_multiplayer_authority():
		globals.clientObj.append(self)
		$Head/Camera3D/Sprite3D.visible = false
		infoCorner.visible = true
		if isServer == false:
			crosshair.visible = true
			setOldUsernames()
			print(commandDictionary.keys())
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			camera.current = is_multiplayer_authority()
		else:
			self.visible = false
			$Body.disabled = true
			UIAudio.visible = false
			
	classAssignment(classInt)

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if is_multiplayer_authority():
		if $Head/Camera3D/pointer.is_colliding():
			var collision_point :Vector3= $Head/Camera3D/pointer.get_collision_point()
			$Crosshair.set_position($Head/Camera3D.unproject_position(collision_point) - $Crosshair.pivot_offset)
		$InfoCorner/WaveInfo.text = "Wave: " + str(globals.waveNum) + " of " + str(globals.waveNumMax) + "\nThere are: " + str(globals.eAlive) + " enemies alive.\nOnion Ring at: " + str(globals.objHP)
		$Crosshair/SpeedLabel.text = str( int( ( velocity * Vector3(1, 0, 1) ).length() ) )
		if globals.chatLog.size() < 5 && chatArray != globals.chatLog:
			for i in globals.chatLog.size():
				if chatArray.size() != globals.chatLog.size():
					chatArray.resize(globals.chatLog.size()+1)
				if globals.chatLog[i] != chatArray[i]:
					chatArray[i] = globals.chatLog[i]
					$InfoCorner/ChatBox.text += globals.chatLog[i]
		elif globals.chatLog.size() > 5 && chatArray != globals.chatLog:
			globals.chatLog.pop_front()
			$InfoCorner/ChatBox.text = ""
			for i in globals.chatLog.size():
				if chatArray.size() != globals.chatLog.size():
					chatArray.resize(globals.chatLog.size()+1)
				if globals.chatLog[i] != chatArray[i]:
					chatArray[i] = globals.chatLog[i]
					$InfoCorner/ChatBox.text += globals.chatLog[i]
					
		if chatting == false && isServer == false:
			if Input.is_action_just_pressed("chat") && chatting != true:
				chatActive()
				
			if Input.is_action_just_pressed("switchWeapon"):
				toggle_weapon_menu()
				
			if Input.is_action_just_pressed("Interact"):
				handleSpawning("ball")
				rpc("spawnRemote", "ball")
			
			if is_menu_open:
				return
			
			# Weapon Check
		if Input.is_action_pressed("primaryFire") && !animPlayer.is_playing() && classInt == ClassType.ROCKET:  # Use enum
				animPlayer.queue("RocketShoot")
				rpc("syncWeapon", {"animPlayer" : animPlayer.get_path(), "animation" : "RocketShoot"})
				handleSpawning("rocket")
				rpc("spawnRemote", "rocket")
		if Input.is_action_just_pressed("primaryFire") && !animPlayer.is_playing() && classInt == ClassType.GRAPPLING_HOOK:  # Use enum
				grappleStart()
		elif Input.is_action_just_released("primaryFire") && classInt == ClassType.GRAPPLING_HOOK:  # Use enum
				grappleStop()
		
		if speedrunning == 1:
			$InfoCorner/SpeedrunTimer.text = get_elapsed_time()

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() && isServer == false:
		if chatting == false:
			var inputDir := Input.get_vector("Left", "Right", "Forward", "Backward")
			wishDir = (head.transform.basis * Vector3(inputDir.x, 0, inputDir.y)).normalized()
			projectedSpeed = (velocity * Vector3(1,0,1)).dot(wishDir)
		
		if grappling == true:
			var targetDir := global_position.direction_to(grapplePoint)
			var targetDist := global_position.distance_to(grapplePoint)
			
			grappleGun.look_at(grapplePoint, Vector3.UP, true)
			grappleGun.get_child(1).scale = Vector3(1, 1, targetDist)
			
			var displacement := targetDist - restLength
			
			var force := Vector3.ZERO
			
			if displacement > 0:
				var springForce := stiffness * displacement
				var springPulse := targetDir * springForce
				
				var velocityDot := velocity.dot(targetDir)
				var damping := -dmp * velocityDot * targetDir
				
				force = springPulse + damping
			
			velocity += force * delta
			
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
		
		tBob += delta * velocity.length() * float(is_on_floor())
		camera.transform.origin = headbob(tBob)
		
		move_and_slide()
		
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c.get_collider() is RigidBody3D:
				c.get_collider().apply_central_impulse(-c.get_normal() * push)
		rpc("remoteSetPos", global_position, head.rotation, camera.rotation)

func _on_input_box_focus_exited() -> void:
	chatting = false

func _on_area_area_entered(area: Area3D) -> void:
	if area.name == "parkourStart":
		start_stopwatch()
	elif area.name == "parkourFinish":
		stop_stopwatch()

func _on_marker_timer_timeout() -> void:
	hitMarker.visible = false

func _on_input_box_text_submitted(new_text: String) -> void:
	if new_text.begins_with("/"):
		var cText := new_text.substr(1)
		commandParser(cText)
		chatting = false
	else:
		globals.chatLog.append(username + ": " + new_text + "\n")
		rpc("syncChat", username + ": " + new_text + "\n")
	chatting = false
	inputBox.release_focus()
	inputBox.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if is_multiplayer_authority() && isServer == false:
		if event is InputEventMouseMotion:
			head.rotate_y(-event.relative.x * lookAroundSpeed)
			camera.rotate_x(-event.relative.y * lookAroundSpeed)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
			

func grappleStart() -> void:
	if ray.is_colliding():
		grapplePoint = ray.get_collision_point()
		animPlayer.queue("GrappleShoot")
		grappling = true
		grappleGun.get_child(1).visible = true

func grappleStop() -> void:
	grappleGun.get_child(1).visible = false
	grappling = false

func classAssignment(cInt: int) -> void:
	if weaponInst and weaponInst.is_inside_tree():
		weaponInst.queue_free()
		weaponInst = null
		animPlayer = null
		grappleGun = null
		
	classInt = cInt as ClassType
	
	if cInt == ClassType.ROCKET:
		weapon = load("res://Objects/objRocketVM.tscn")
		weaponInst = weapon.instantiate()
		weaponInst.set_multiplayer_authority(get_multiplayer_authority())
		animPlayer = weaponInst.get_child(0)
		camera.call_deferred("add_child", weaponInst)
		
	elif cInt == ClassType.GRAPPLING_HOOK:
		weapon = load("res://Objects/objGrapplingVM.tscn")
		weaponInst = weapon.instantiate()
		animPlayer = weaponInst.get_child(0)
		grappleGun = weaponInst
		ray.position = Vector3(0, 0, -0.6)
		ray.set_target_position(Vector3(0, 0, -200))
		camera.call_deferred("add_child", weaponInst)

func toggle_weapon_menu() -> void:
	is_menu_open = !is_menu_open
	if is_menu_open:
		if weaponMenu:
			weaponMenu.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		if weaponMenu:
			weaponMenu.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_weapon_menu_selected(choice: int) -> void:
	match choice:
		0:
			currentWeapon = "rocket"
			classAssignment(0)
		1: 
			currentWeapon = "grapple"
			classAssignment(1)
		_: return
		
	is_menu_open = false
	if weaponMenu:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		weaponMenu.hide()

func commandParser(command: String) -> void:
	# Define a dictionary where the key is the command and the value is a Callable (function reference) that modifies the respective variable
	
	# Iterate through the dictionary keys to find the command in the input
	for i: String in commandDictionary.keys():
		if command.begins_with(i):
			# Erase the command part from the string, leaving only the value
			var cmd := command.erase(0, i.length()+1)
			var value := cmd # Erases the command part (e.g., "push ") from the input string
			
			# Call the corresponding function using .call()
			commandDictionary[i].call(value)
			break

func setOldUsernames() -> void:
	for i in globals.clientObj.size():
		print("Set name " + str(globals.clientObj[i].username) + " to player " + str(globals.clientObj[i]))
		globals.clientObj[i].get_child(1).get_child(0).text = globals.clientObj[i].username

func start_stopwatch() -> void:
	if speedrunning == 0:
		$InfoCorner/SpeedrunTimer.visible = true
		speedrunning = 1
	start_time = Time.get_ticks_msec()

func stop_stopwatch() -> void:
	if speedrunning == 1:
		elapsed_time = Time.get_ticks_msec() - start_time
		speedrunning = 0

func get_elapsed_time() -> String:
	var time_in_ms: int = elapsed_time
	if speedrunning == 1:
		time_in_ms = Time.get_ticks_msec() - start_time
	
	@warning_ignore("integer_division")
	var minutes: int = time_in_ms / 60000
	@warning_ignore("integer_division")
	var seconds: int = (time_in_ms / 1000) % 60
	var milliseconds: int = time_in_ms % 1000
	
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]

#region Movement
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
	
	velocity.y -= globals.gravity * delta

func groundMove(delta: float) -> void:
	applyAccel(accel, groundedMax, delta)
	
	if Input.is_action_just_pressed("Jump") && chatting == false || Input.is_action_pressed("Jump") && autoBhop == true && chatting == false:
		velocity.y = jumpVelocity
		
	if grounded == prevGrounded:
		applyFriction(delta)
	
	if is_on_wall():
		clipVelocity(get_wall_normal(), 1, delta)
#endregion

#region Spawn Management
func spawnEnemy() -> void:
	var enemyInst := enemy.instantiate()
	var ray_data := self.getMouseRay()
	var result : Object = ray_data.result
	var ray_target : Object = ray_data.ray_target
	# Defer adding the instance to the scene tree to ensure it's properly initialized
	get_tree().get_root().call_deferred("add_child", enemyInst)
	# Use call_deferred to set the position after the instance is added to the tree
	if result:
		enemyInst.call_deferred("set_position", result.position)
	else:
		enemyInst.call_deferred("set_position", ray_target)

func spawnRocket(rot: Vector3) -> void:
	var rocketInst := rocket.instantiate()
	rocketInst.FORCE = rocketForce
	rocketInst.SPEED = rocketSpeed
	rocketInst.RADIUS = rocketRadius
	rocketInst.position = ray.global_position
	rocketInst.spawner = self
	rocketInst.pSpeed = float((velocity * Vector3(1, 0, 1)).length())
	rocketInst.rotation = rot
	get_parent().add_child(rocketInst)

func spawnBall(red: float, green: float, blue: float) -> void:
	var randomColor := StandardMaterial3D.new()
	randomColor.albedo_color = Color(red, green, blue, 1.0)
	var ballInst := ball.instantiate()
	var ray_data := self.getMouseRay()
	var result : Dictionary = ray_data.result
	var ray_target : Vector3 = ray_data.ray_target
	# Defer adding the instance to the scene tree to ensure it's properly initialized
	get_tree().get_root().add_child(ballInst)
	# Use call_deferred to set the position after the instance is added to the tree
	if result:
		ballInst.call_deferred("set_position", result.position)
	else:
		ballInst.call_deferred("set_position", ray_target)
	ballInst.get_child(0).material_override = randomColor

func handleSpawning(type: String) -> void:
	if type == "ball":
		var r := randf_range(0.01, 1.0)
		var g := randf_range(0.01, 1.0)
		var b := randf_range(0.01, 1.0)
		spawnBall(r,g,b)
	
	elif type == "rocket":
		var rot : Vector3 = $Head/Camera3D.rotation + $Head.rotation
		spawnRocket(rot)
	
	elif type == "enemy":
		spawnEnemy()
#endregion

func getMouseRay() -> Dictionary:
	var mousePos := get_viewport().get_mouse_position()
	var rayOrigin : Vector3 = camera.project_ray_origin(mousePos)
	var rayDir : Vector3 = camera.project_ray_normal(mousePos)
	var rayLen := 100.0
	var rayTarget := rayOrigin + rayDir * rayLen

	var rayQuery := PhysicsRayQueryParameters3D.new()
	rayQuery.from = rayOrigin
	rayQuery.to = rayTarget

	var spaceState := get_world_3d().direct_space_state
	var result := spaceState.intersect_ray(rayQuery)

	# Return both the result and rayTarget in a dictionary
	return {
		"result": result,
		"ray_target": rayTarget
	}

func headbob(time: float) -> Vector3:
	var pos := Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func chatActive() -> void:
	chatting = true
	inputBox.grab_focus()

#region RPC calls
@rpc("unreliable")
func remoteSetPos(authorityPosition: Vector3, headRot: Vector3, camRot: Vector3) -> void:
	global_position = authorityPosition
	head.rotation = headRot
	camera.rotation = camRot

@rpc("unreliable")
func syncWeapon(weaponInfo: Dictionary) -> void:
	for key: String in weaponInfo.keys():
		if key == "animPlayer":
			get_node(weaponInfo["animPlayer"]).queue(weaponInfo["animation"])

@rpc 
func spawnRemote(type : String) -> void:
	print("Spawning ", type)
	handleSpawning(type)
#endregion
