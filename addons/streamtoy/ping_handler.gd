extends StreamToyHandler
class_name PingHandler


# The client is not responding anymore. Disconnect it
signal client_not_responding(client_id)


# A hash of timers for each client to allow for timeouts
var _client_timers: Dictionary = {}

# The maximum time until a client will be assumed to be offline because no
# heartbeat was received. In Seconds
var _client_timeout: int = 300


func _init(client_timeout):
	_client_timeout = client_timeout
	

func cleanup(client_id):
	if client_id in _client_timers:
		_client_timers[client_id].stop()
	_client_timers.erase(client_id)


# Add a new client to the ping handler. Will start the timeout handler for this
# client
#
# #### Parameters
# - client_id: Id of the connecting client
func add_client(client_id):
	var timer = Timer.new()
	timer.name = "Timer_%s" % client_id
	add_child(timer)
	timer.start(_client_timeout)
	timer.connect("timeout", self, "_disconnect_client", [client_id])
	_client_timers[client_id] = timer


# The client did not react anymore, disconnect it
func disconnect_client(client_id):
	emit_signal("client_not_responding", client_id)
	
	
# Called by the client to make sure it's still online
remote func ping():
	var client_id = get_tree().get_rpc_sender_id()
	if !get_node('/root/Auth').is_authenticated(client_id):
		print("Client %s tried to ping without authenticating first" % client_id)
		return
	if client_id in self._client_timers:
		self._client_timers[client_id].start(_client_timeout)
	
