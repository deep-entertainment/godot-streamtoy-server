extends Node
class_name StreamToyServer


var _bind_address: String = '*'
var _http_port: int = 8080
var _server: HttpServer
var _rpc_server: NetworkedMultiplayerENet
var _port: int = 8081
var _max_clients: int = 32
var _base_url: String = ""

var _test_mode: bool = false

var _client_registry: Array = []

var _handlers: Array


# Start the server
func start():
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
	
	self._server = HttpServer.new()
	add_child(self._server)
	self._server.bind_address = self._bind_address
	self._server.port = self._http_port
	
	# Twitch handler
	
	var twitch_handler = TwitchHandler.new()
	twitch_handler.add_router(self._server, self._base_url, self._test_mode)
	twitch_handler.name = "StreamToyTwitch"
	get_tree().root.add_child(twitch_handler)
	
	self._server.start()
	print("Streamtoy HTTP server started on http://%s:%d" % [self._bind_address, self._http_port])
	
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
	for handler in self._handlers:
		handler.unsubscribe(id)
	_client_registry.erase(id)
