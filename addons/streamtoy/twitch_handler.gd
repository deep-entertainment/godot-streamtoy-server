# A twitch handler for StreamToy
extends StreamToyHandler
class_name TwitchHandler


# The secret to secure messaging with the twitch api
var _twitch_secret: PoolByteArray

# Whether we're in test mode
var _test_mode: bool = false

# The twitch API token
var _twitch_api_token: String = ""

# The twich client id
var _twitch_client_id: String = ""

# The callback URL of the server
var _callback_url: String = ""

# A list of subscriptions per client
var _subscription_registry: Dictionary = {}

# Twitch access token
var _access_token: String = ""

# The unix timestamp at which the access token expires
var _expires_timestamp: int = -1


# Add our eventsub router
func add_router(server: HttpServer, base_url: String, test_mode: bool = false):
	self._test_mode = test_mode
	self._callback_url = "%s/eventsub" % base_url
	if OS.has_environment('STREAMTOY_TWITCH_API_TOKEN'):
		self._twitch_api_token = OS.get_environment('STREAMTOY_TWITCH_API_TOKEN')
	else:
		printerr("No twitch API token specified. Use STREAMTOY_TWITCH_API_TOKEN")
		get_tree().quit(1)
	if OS.has_environment('STREAMTOY_TWITCH_API_CLIENT_ID'):
		self._twitch_client_id = OS.get_environment('STREAMTOY_TWITCH_API_CLIENT_ID')
	else:
		printerr("No twitch API token specified. Use STREAMTOY_TWITCH_API_CLIENT_ID")
		get_tree().quit(1)
	if OS.has_environment('STREAMTOY_TWITCH_SECRET'):
		self._twitch_secret = OS.get_environment('STREAMTOY_TWITCH_SECRET').to_ascii()
	else:
		printerr("No secret specified. Use STREAMTOY_TWITCH_SECRET")
		get_tree().quit(1)
		
	var router = EventSubRouter.new()
	router.secret = self._twitch_secret
	router.connect("notification", self, "_on_eventsub_notification")
	server.register_router("/eventsub", router)


# Subscribe to a specific twitch event type and return
# the subscription id
#
# #### Params
# - subscription_type: Type of the subscription (see https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types)
# - condition: The condition to honor for the subscription (see https://dev.twitch.tv/docs/eventsub/eventsub-reference)
# - version_number: Version number of the subscription type
remote func twitch_subscribe(
	subscription_type: String, 
	condition: Dictionary, 
	version_number: String = "1"
) -> String:
	var client_id = get_tree().get_rpc_sender_id()
	
	print_debug("Received subscription for %s/%s on client %s with the following condition: %s" % [
		version_number,
		subscription_type,
		client_id,
		JSON.print(condition)
	])
	
	if not client_id in _subscription_registry:
		_subscription_registry[client_id] = []
	
	if self._test_mode:
		var subscription_id = "test-%s" % subscription_type
		print_debug("We're in test mode. Returning subscription_id: %s" % subscription_id)
		_subscription_registry[client_id].push_back(subscription_id)
		rpc_id(
			client_id, "subscribed", 
			subscription_id, 
			subscription_type, 
			condition, 
			version_number
		)
		return
	
	if not self._check_token():
		yield(self._update_token(), "completed")
	
	var request_body = JSON.print({
		"type": subscription_type,
		"version": version_number,
		"condition": condition,
		"transport": {
			"method": "webhook",
			"callback": self._callback_url,
			"secret": self._twitch_secret.get_string_from_ascii()
		}
	})
	var request_headers = PoolStringArray([
		"Authorization: Bearer %s" % self._access_token,
		"Client-Id: %s" % self._twitch_client_id,
		"Content-Type: application/json"
	])
	var http = HTTPRequest.new()
	add_child(http)
	http.request(
		"https://api.twitch.tv/helix/eventsub/subscriptions", 
		request_headers,
		true,
		HTTPClient.METHOD_POST,
		request_body
	)
	var response = yield(http, "request_completed")
	remove_child(http)
	if response[1] != 202:
		printerr(
			"Trying to subscribe to %s for %s failed with status %d: %s" % [
				subscription_type,
				JSON.print(condition),
				response[1],
				(response[3] as PoolByteArray).get_string_from_utf8()
			]
		)
		return
	else:
		var body = JSON.parse((response[3] as PoolByteArray).get_string_from_utf8()).result
		var subscription_id = body["data"]["id"]
		_subscription_registry[client_id].push_back(subscription_id)
		rpc_id(
			client_id, "subscribed", 
			subscription_id, 
			subscription_type, 
			condition, 
			version_number
		)
		return


# Unsubscribe all registered subscriptions for the client
func cleanup(client_id) -> void:
	print_debug("Removing all subscriptions for client %d" % client_id)
	for subscription_id in self._subscription_registry[client_id]:
		self.unsubscribe(subscription_id)
	

# Unsubscribe a subscription
#
# #### Parameters
# - subscription_id: The ID of the subscription to unsubscribe
func unsubscribe(subscription_id) -> void:
	if self._test_mode:
		return
		
	if not self._check_token():
		yield(self._update_token(), "completed")
		
	var request_headers = PoolStringArray([
		"Authorization: Bearer %s" % self._access_token,
		"Client-Id: %s" % self._twitch_client_id
	])
	var http = HTTPRequest.new()
	http.request(
		"https://api.twitch.tv/helix/eventsub/subscriptions?id=%s" % subscription_id, 
		request_headers,
		true,
		HTTPClient.METHOD_DELETE
	)
	var response = yield(http, "request_completed")
	if response[1] >= 400:
		printerr("Can't revoke subscription id %d: %s" % [
			response[1],
			(response[3] as PoolByteArray).get_string_from_utf8()
		])


# Run eventsub_notification on the client that subscribed
#
# #### Params
# - subscription_id: ID of subscription
# - event: Event dictionary
func _on_eventsub_notification(
	subscription_id: String, 
	subscription_type: String, 
	event: Dictionary
):
	var found = false
	print_debug("Searching for subscription")
	for client_id in self._subscription_registry:
		print_debug("Searching for subscriptions of client %s" % client_id)
		for client_subscription in self._subscription_registry[client_id]:
			print_debug("Testing subscription %s" % client_subscription)
			if self._test_mode and client_subscription == "test-%s" % subscription_type:
				print_debug("Matched. Calling client")
				rpc_id(client_id, "eventsub_notification", "test-%s" % subscription_type, event)
				found = true
			elif not self._test_mode and client_subscription == subscription_id:
				print_debug("Matched. Calling client")
				rpc_id(client_id, "eventsub_notification", subscription_id, event)
				found = true
	if not found:
		print_debug("No subscription matched. Unsubscribing.")
		self.unsubscribe(subscription_id)


# Check if our access token is still valid
func _check_token() -> bool:
	if self._access_token == "":
		return false
	
	if OS.get_unix_time() > self._expires_timestamp:
		return false
	
	return true


# Update the twitch access token
func _update_token() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request(
		"%s?client_id=%s&client_secret=%s&grant_type=client_credentials" % [
			"https://id.twitch.tv/oauth2/token",
			self._twitch_client_id,
			self._twitch_api_token
		],
		PoolStringArray([]),
		true,
		HTTPClient.METHOD_POST
	)
	var response = yield(http, "request_completed")
	remove_child(http)
	if response[1] != 200:
		printerr(
			"Trying to fetch access token on Twitch failed with status %d: %s" % [
				response[0],
				(response[3] as PoolByteArray).get_string_from_utf8()
			]
		)
	else:
		var body = JSON.parse((response[3] as PoolByteArray).get_string_from_utf8()).result
		self._access_token = body["access_token"]
		self._expires_timestamp = OS.get_unix_time() + int(body["expires_in"])
