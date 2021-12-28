# A base class for all HTTP routers
extends Object
class_name HttpRouter


func handle_get(request: HttpRequest, response: HttpResponse):
	response.send(405, "GET not allowed")

func handle_post(request: HttpRequest, response: HttpResponse):
	response.send(405, "POST not allowed")

func handle_head(request: HttpRequest, response: HttpResponse):
	response.send(405, "HEAD not allowed")

func handle_put(request: HttpRequest, response: HttpResponse):
	response.send(405, "PUT not allowed")

func handle_patch(request: HttpRequest, response: HttpResponse):
	response.send(405, "PATCH not allowed")

func handle_delete(request: HttpRequest, response: HttpResponse):
	response.send(405, "DELETE not allowed")
	
func handle_options(request: HttpRequest, response: HttpResponse):
	response.send(405, "OPTIONS not allowed")
