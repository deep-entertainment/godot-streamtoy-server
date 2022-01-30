# A server backend to connect to streaming provider APIs
extends Node
class_name StreamToyServer


# The IP address to bind to
var _bind_address: String = '*'

# The port of the HTTP server
var _http_port: int = 8080

# The UDP port of the ENET server
var _port: int = 8081

# The http server object
var _server: HttpServer

# The ENET server object
var _rpc_server: NetworkedMultiplayerENet

# The maximum number of ENET clients
var _max_clients: int = 32

# The base URL of the HTTP server
var _base_url: String = ""

# Whether we're in test mode
var _test_mode: bool = false

# A list of connected client ids
var _client_registry: Array = []

# A list of available streaming provider handlers
var _handlers: Array


# Start the server
func start():
	# Basic configuration
	
	if OS.has_environment('STREAMTOY_BIND_ADDRESS'):
		self._bind_address = OS.get_environment('STREAMTOY_BIND_ADDRESS')
	if OS.has_environment('STREAMTOY_HTTP_PORT'):
		self._http_port = int(OS.get_environment('STREAMTOY_HTTP_PORT'))
	if OS.has_environment('STREAMTOY_PORT'):
		self._port = int(OS.get_environment('STREAMTOY_PORT'))
	
	if OS.has_environment('STREAMTOY_BASE_URL'):
		self._base_url = OS.get_environment('STREAMTOY_BASE_URL')
	else:
		self._base_url = "http://%s:%d" % [
			self._bind_address,
			self._http_port
		]
	
	if OS.has_environment('STREAMTOY_TEST'):
		print("Starting streamtoy in test mode")
		self._test_mode = true
	
	# HTTP server
	
	self._server = HttpServer.new()
	add_child(self._server)
	self._server.bind_address = self._bind_address
	self._server.port = self._http_port
	
	# Twitch handler
	
	var twitch_handler = TwitchHandler.new()
	twitch_handler.name = "StreamToyTwitch"
	get_tree().root.add_child(twitch_handler)
	twitch_handler.add_router(self._server, self._base_url, self._test_mode)
	self._handlers.push_back(twitch_handler)
	
	# Start the server
	
	self._server.start()
	print("Streamtoy HTTP server started on http://%s:%d" % [self._bind_address, self._http_port])
	
	# ENET server
	
	_rpc_server = NetworkedMultiplayerENet.new()
	_rpc_server.set_bind_ip(_bind_address)
	var error = _rpc_server.create_server(self._port, self._max_clients)
	if error != OK:
		printerr("Can't create ENET server: %d" % error)
		get_tree().quit(1)
	get_tree().network_peer = _rpc_server
	
	print("StreamToy ENET server started on %s:%d udp" % [self._bind_address, self._port])
	get_tree().connect("network_peer_connected", self, "_on_network_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_network_peer_disconnected")


# Stop the server
func stop():
	for client in self._client_registry:
		print_debug("Closing client %d" % client)
		_on_network_peer_disconnected(client)
	self._rpc_server.close_connection(0)
	self._server.stop()
	

# A client has connected to the server
#
# #### Params
# - id: Id of the client
func _on_network_peer_connected(id: int):
	if id in self._client_registry:
		_on_network_peer_disconnected(id)
	_client_registry.push_back(id)


# A client has disconnected, terminate all subscriptions
#
# #### Params
# - id: Id of the client
func _on_network_peer_disconnected(id: int):
	# Terminate all the client in all handlers
	print_debug("Client %d disconnected. Cleaning up" % id)
	for handler in self._handlers:
		handler.cleanup(id)
	_client_registry.erase(id)
