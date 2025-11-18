extends Node3D


@export var SPEED: float = 0.0
@export var FORCE: float = 0.0
@export var RADIUS: Vector3

var spawner : Node3D = null
var pSpeed := 0.0
var colliding := false

@onready var model := $modRocket
@onready var ray := $RayCast3D
@onready var explode := $"Explosion Radius/CPUParticles3D"
@onready var radius := $"Explosion Radius"


func _ready() -> void:
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
	if body.is_in_group("enemies") && is_multiplayer_authority():
		if spawner and spawner.has_method("deal_damage"):
			spawner.deal_damage(body, pSpeed)

func repelBody(body: Object) -> void:
	var explosionPos : Vector3 = radius.global_position
	var bodyPos : Vector3 = body.global_position
	var dir := bodyPos - explosionPos
	
	dir = dir.normalized()
	
	var pressure := dir * FORCE
	
	if body is CharacterBody3D:
		body.velocity += pressure
	elif body is RigidBody3D:
		body.apply_central_impulse(pressure*2)

func _on_cpu_particles_3d_finished() -> void:
	queue_free()
