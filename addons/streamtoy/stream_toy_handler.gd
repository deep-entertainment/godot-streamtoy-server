# An abstract class every StreamToy handler has to extend
extends Node
class_name StreamToyHandler


# Add a router to the HTTP server
#
# #### Parameters
# - server: The HTTP server object
# - base_url: The HTTP server's base url
# - test_mode: Whether we're in test mode
func add_router(server: HttpServer, base_url: String, test_mode: bool):
	pass


# Cleanup resources for the given client
# (called when the server is stopped or a client disconnects)
#
# #### Parameters
# - client_id: The client id of the registered client
func cleanup(client_id):
	pass # Replace with function body.

