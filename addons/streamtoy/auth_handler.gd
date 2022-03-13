# A handler for StreamToy to handle authentications
extends StreamToyHandler
class_name AuthHandler


# A list of authenticated client ids
var authenticated_clients: Array = []


# The token required to connect to StreamToy
var _token: String


func _init(token: String):
	_token = token


# Check whether the given client is authenticated
#
# #### Parameters
# - client_id: Client id to check
func is_authenticated(client_id) -> bool:
	return authenticated_clients.has(client_id)


func cleanup(client_id):
	authenticated_clients.erase(client_id)


# Authenticate a client
#
# #### Parameters
# - token: Token to authenticate with
remote func auth(token: String):
	var client_id = get_tree().get_rpc_sender_id()
	if token == _token:
		authenticated_clients.push_back(get_tree().get_rpc_sender_id())
		rpc_id(client_id, "auth_successful")
	else:
		rpc_id(client_id, "auth_unsuccessful")
