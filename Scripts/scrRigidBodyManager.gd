extends RigidBody3D

var culling := false
@onready var timer := $Timer

@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	if sleeping == true && culling == false:
		print("Starting sleep timer for: ", self)
		globals.chatLog.append("Starting sleep timer for: " + str(self) + "\n")
		timer.start(10.0)
		culling = true
	elif sleeping == false && culling == true:
		print("Stopping sleep timer for: ", self)
		globals.chatLog.append("Stopping sleep timer for: " + str(self) + "\n")
		culling = false
		timer.stop()

func _on_timer_timeout() -> void:
	handleDeath()

func handleDeath() -> void:
	if is_multiplayer_authority():
		print("Culling Body: " + str(self))
		globals.chatLog.append("Culling Body: " + str(self) + "\n")
		queue_free()

@warning_ignore("unused_parameter")
func _on_body_entered(body: Node) -> void:
	$AudioStreamPlayer3D.play()
