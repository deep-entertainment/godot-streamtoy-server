extends Node
class_name HttpServer


export(String) var bind_address: String = "*"
export(int) var port: int = 8080
export(String) var server_identifier: String = "GodotTPD"

var _server: TCP_Server
var _clients: Array
var _client_request: Dictionary
var _client_busy: Array
var _routers: Array = []
var _method_regex: RegEx = RegEx.new()
var _header_regex: RegEx = RegEx.new()


func _init() -> void:
	_method_regex.compile("^(?<method>GET|POST|HEAD|PUT|PATCH|DELETE|OPTIONS) (?<path>[^ ]+) HTTP/1.1$")
	_header_regex.compile("^(?<key>[^:]+): (?<value>.+)$")


func register_router(path: String, router: HttpRouter):
	var path_regex = RegEx.new()
	path_regex.compile(path)
	_routers.push_back({
		"path": path_regex,
		"router": router
	})


# Handle all incoming requests
func _process(_delta: float) -> void:
	if _server:
		var new_client = _server.take_connection()
		if new_client:
			self._clients.append(new_client)
		for client in self._clients:
			if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
				var bytes = client.get_available_bytes()
				if bytes > 0:
					var request_string = client.get_string(bytes)
					self._handle_request(client, request_string)


# Start the server
func start():
	self._server = TCP_Server.new()
	self._server.listen(self.port, self.bind_address)


func stop():
	for client in self._clients:
		client.disconnect_from_host()
	self._clients.clear()
	self._server.stop()
	

func _handle_request(client: StreamPeer, request: String):
	for line in request.split("\r\n"):
		var method_matches = _method_regex.search(line)
		var header_matches = _header_regex.search(line)
		if method_matches:
			_client_request[client] = {
				"method": method_matches.get_string("method"),
				"path": method_matches.get_string("path"),
				"headers": {},
				"body": ""
			}
		elif header_matches:
			_client_request[client]["headers"][header_matches.get_string("key")] = \
			header_matches.get_string("value")
		elif client in _client_request:
			_client_request[client].body += line
	self._perform_current_request(client)


func _perform_current_request(client: StreamPeer):
	if client in self._client_request:
		var request_info = self._client_request.get(client)
		for router in self._routers:
			var matches = router.path.search(request_info.path)
			if matches:
				var request = HttpRequest.new()
				request.headers = request_info.headers
				request.body = request_info.body
				request.query_match = matches
				var response = HttpResponse.new()
				response.client = client
				response.server_identifier = server_identifier
				match request_info.method:
					"GET":
						router.router.handle_get(request, response)
					"POST":
						router.router.handle_post(request, response)
					"HEAD":
						router.router.handle_head(request, response)
					"PUT":
						router.router.handle_put(request, response)
					"PATCH":
						router.router.handle_patch(request, response)
					"DELETE":
						router.router.handle_delete(request, response)
					"OPTIONS":
						router.router.handle_options(request, response)
		self._client_request.erase(client)
		self._client_busy.erase(client)

