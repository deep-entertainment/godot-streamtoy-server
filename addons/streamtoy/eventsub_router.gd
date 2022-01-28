extends HttpRouter
class_name EventSubRouter


signal notification(subscription_id, subscription_type, event)


var key: PoolByteArray


func handle_post(request: HttpRequest, response: HttpResponse):
	var body = JSON.parse(request.body)
	self.verify_twitch_request(request, response)
	if body.error != OK or not "Twitch-Eventsub-Message-Type" in request.headers:
		response.send(400, "Body not parseable: %s" % body.error_string)
	else:
		var messageType = request.headers["Twitch-Eventsub-Message-Type"]
		
		match messageType:
			"webhook_callback_verification":
				print_debug("Twitch called for callback verification")
				response.send(200, body.result.get("challenge"), "text/plain")
			"notification":
				print_debug("Notification received for subscription %s (%s)" % [
					body.result.subscription.id, 
					body.result.subscription.type
				])
				emit_signal(
					"notification", 
					body.result.subscription.id, 
					body.result.subscription.type, 
					body.result.event
				)
				response.send(204, "", "text/plain")
			"revocation":
				print_debug("Twitch revoked subscription %s with status: %s" % [
					body.result.get("subscription").get("id"),
					body.result.get("subscription").get("status")
				])
				response.send(204, "", "text/plain")


# Verify a request coming from twitch based on the verification process
# https://dev.twitch.tv/docs/eventsub/handling-webhook-events/#verifying-the-event-message
#
# #### Parameters
# - request: The incoming http request
# - response: The outgoing http response
func verify_twitch_request(request: HttpRequest, response: HttpResponse):
	print_debug("Verifying twitch request")
	var crypto = Crypto.new()
	var headers = ("%s%s%s" % [
		request.headers['Twitch-Eventsub-Message-Id'],
		request.headers['Twitch-Eventsub-Message-Timestamp'],
		request.body
	])
	var digest = crypto.hmac_digest(
		HashingContext.HASH_SHA256,
		self.key, 
		headers.to_ascii()
	)
	if not "sha256=%s" % digest.hex_encode() == request.headers['Twitch-Eventsub-Message-Signature']:
		printerr("Invalid message signature found")
		response.send(400, "Invalid message signature found.")
	
	
