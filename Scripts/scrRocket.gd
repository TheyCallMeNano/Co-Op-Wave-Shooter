extends Node3D


@export var SPEED: float = 0.0
@export var FORCE: float = 0.0
@export var RADIUS: Vector3

var spawner = PackedScene
var pSpeed = 0.0
var colliding = false

@onready var model = $modRocket
@onready var ray = $RayCast3D
@onready var explode = $"Explosion Radius/CPUParticles3D"
@onready var radius = $"Explosion Radius"


func _ready():
	$"Explosion Radius".scale = RADIUS

func _process(delta: float) -> void:
	if ray.is_colliding() && colliding == false:
		if ray.get_collider().name == "WorldFloor":
			print("Rocket went through the floor at: " + str(global_position))
			queue_free()
		model.visible = false
		explode.emitting = true
		radius.monitoring = true
		colliding = true
	elif !ray.is_colliding():
		position += transform.basis * Vector3(0, 0, -SPEED) * delta


func _on_timer_timeout() -> void:
	print("Rocket has timedout!")
	queue_free()


func _on_explosion_radius_body_entered(body: Node3D) -> void:
	if body.is_in_group("bodies"):
		repelBody(body)
	if body.is_in_group("enemies"):
		var critChance = randf_range(spawner.critBucketCur, spawner.critBucketMax)
		print(critChance)
		var dmg
		if critChance >= 750.0:
			if pSpeed != 0:
				dmg = 20.0 + (pSpeed * 0.35) * 3.0
			else:
				dmg = 20.0 + (1 * 1.35) * 3.0
			print("crit dmg: ", dmg)
			if spawner.critBucketCur <= 250:
				spawner.critBucketCur = spawner.critBucketMin
			else:
				spawner.critBucketCur += -250 + dmg
		else:
			dmg = 20.0 + (pSpeed * 0.35)
			spawner.critBucketCur += dmg
		if dmg >= body.hp:
			spawner.hitMarker.visible = true
			spawner.hitMarker.texture = load("res://hitmarkerLethal.png")
			spawner.timer.start(0.25)
			spawner.UIAudio.stream = load("res://killsound.ogg")
			spawner.UIAudio.play()
		else:
			spawner.hitMarker.visible = true
			spawner.hitMarker.texture = load("res://hitmarkernonlethal.png")
			spawner.timer.start(0.25)
			spawner.UIAudio.stream = load("res://hitsound.ogg")
			spawner.UIAudio.play()
		body.hp -= dmg
		globals.chatLog.append(spawner.username + " did " + str(int(dmg)) + " to " + body.name + "\n")

func repelBody(body):
	var explosionPos = radius.global_position
	var bodyPos = body.global_position
	var dir = bodyPos - explosionPos
	
	dir = dir.normalized()
	
	var pressure = dir * FORCE
	
	if body is CharacterBody3D:
		body.velocity += pressure
	elif body is RigidBody3D:
		body.apply_central_impulse(pressure*2)

func _on_cpu_particles_3d_finished() -> void:
	queue_free()
