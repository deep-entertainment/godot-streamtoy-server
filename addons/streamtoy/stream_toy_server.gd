extends Node
class_name StreamToyServer

var _bind_address: String = '*'
var _port: int = 8080
var _server: HttpServer


# Start the server
func start():
	if OS.has_environment('STREAMTOY_PORT'):
		self._port = int(OS.get_environment('STREAMTOY_PORT'))
	if OS.has_environment('STREAMTOY_BIND_ADDRESS'):
		self._bind_address = OS.get_environment('STREAMTOY_BIND_ADDRESS')
		
	self._server = HttpServer.new()
	add_child(self._server)
	self._server.bind_address = self._bind_address
	self._server.port = self._port
	self._server.register_router("/eventsub", EventSubRouter.new())
	self._server.start()


func stop():
	self._server.stop()
	
