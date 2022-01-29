# A server backend to connect to streaming provider APIs
tool
extends EditorPlugin


var server: StreamToyServer


func _enter_tree() -> void:
	call_deferred("_setup_server")
	

# Set up the server and start it
func _setup_server() -> void:
	server = StreamToyServer.new()
	add_child(server)
	server.start()
	

func _exit_tree() -> void:
	server.stop()
	remove_child(server)
