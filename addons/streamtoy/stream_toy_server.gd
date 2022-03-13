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
var _rpc_server: WebSocketServer

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
	
	var token = ""
	
	if OS.has_environment('STREAMTOY_TOKEN'):
		token = OS.get_environment('STREAMTOY_TOKEN')
	else:
		print(
			"No stream toy token found. Please set STREAMTOY_TOKEN to "+
			"enable authentication"
		)
	
	var client_timeout = 300
	if OS.has_environment('STREAMTOY_CLIENT_TIMEOUT'):
		client_timeout = int(OS.get_environment('STREAMTOY_CLIENT_TIMEOUT'))
	
	# HTTP server
	
	self._server = HttpServer.new()
	add_child(self._server)
	self._server.bind_address = self._bind_address
	self._server.port = self._http_port
	
	# Ping handler
	
	var ping_handler = PingHandler.new(client_timeout)
	ping_handler.name = "Ping"
	ping_handler.connect("client_not_responding", self, "remove_client")
	get_tree().root.add_child(ping_handler)
	self._handlers.push_back(ping_handler)

	# Auth handler
	
	var auth_handler = AuthHandler.new(token)
	auth_handler.name = "Auth"
	get_tree().root.add_child(auth_handler)
	self._handlers.push_back(auth_handler)
	
	# Twitch handler
	
	var twitch_handler = TwitchHandler.new()
	twitch_handler.name = "StreamToyTwitch"
	get_tree().root.add_child(twitch_handler)
	twitch_handler.add_router(self._server, self._base_url, self._test_mode)
	self._handlers.push_back(twitch_handler)
	
	# Start the server
	
	self._server.start()
	print("Streamtoy HTTP server started on http://%s:%d" % [self._bind_address, self._http_port])
	
	# Websocket server
	
	_rpc_server = WebSocketServer.new()
	_rpc_server.set_bind_ip(_bind_address)
	var error = _rpc_server.listen(self._port, PoolStringArray(), true)
	if error != OK:
		printerr("Can't create Websocket server: %d" % error)
		get_tree().quit(1)
	get_tree().network_peer = _rpc_server
	
	print("StreamToy WebSocket server started on %s:%d" % [self._bind_address, self._port])
	get_tree().connect("network_peer_connected", self, "_on_network_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_network_peer_disconnected")


# Stop the server
func stop():
	for client in self._client_registry:
		print_debug("Closing client %d" % client)
		_on_network_peer_disconnected(client)
	self._rpc_server.close_connection(0)
	self._server.stop()
	
	
func remove_client(client_id: int):
	# Terminate all the client in all handlers
	print_debug("Client %d disconnected. Cleaning up" % client_id)
	for handler in self._handlers:
		handler.cleanup(client_id)
	_client_registry.erase(client_id)


# A client has connected to the server
#
# #### Params
# - id: Id of the client
func _on_network_peer_connected(id: int):
	if id in self._client_registry:
		_on_network_peer_disconnected(id)
	_client_registry.push_back(id)
	get_node("/root/Ping").add_client(id)


# A client has disconnected, terminate all subscriptions
#
# #### Params
# - id: Id of the client
func _on_network_peer_disconnected(client_id: int):
	remove_client(client_id)
