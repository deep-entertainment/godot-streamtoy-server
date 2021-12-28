tool
extends EditorPlugin

var server: StreamToyServer


func _enter_tree() -> void:
	server = StreamToyServer.new()
	add_child(server)
	server.start()
		

func _exit_tree() -> void:
	server.stop()
