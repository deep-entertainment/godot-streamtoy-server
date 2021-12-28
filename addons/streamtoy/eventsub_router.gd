extends HttpRouter
class_name EventSubRouter


func handle_post(request: HttpRequest, response: HttpResponse):
	var body = JSON.parse(request.body)
	if body.error != OK:
		response.send(400, "Body not parseable: %s" % body.error_string)
	else:
		response.send(200, body.result.get("challenge"), "text/plain")
