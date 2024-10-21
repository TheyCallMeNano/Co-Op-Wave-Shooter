extends Area3D


func _on_body_entered(body: Node3D) -> void:
	if !body.is_in_group("players"):
		print("Culling body that fell out of bounds at:\n" + str(body.position) + "\n" + str(body))
		globals.chatLog.append("Culling body that fell out of bounds at:\n" + str(body.position) + "\n" + str(body) + "\n")
		if body.has_method("airMove"):
			globals.eAlive -= 1
		body.queue_free()
	else:
		print("Teleporting player that fell out of bounds at:\n" + str(body.position) + " " + str(body))
		globals.chatLog.append("Teleporting player that fell out of bounds at:\n" + str(body.position) + "\n" + str(body) + "\n")
		body.position = Vector3(0, 5, 0)
