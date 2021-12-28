extends Object
class_name HttpResponse


var client: StreamPeer
var server_identifier: String = "GodotTPD"


func send(status: int, data: String, content_type: String = "text/html"):
	client.put_data(("HTTP/1.1 %d OK\n" % status).to_ascii())
	client.put_data(("Server: %s\n" % server_identifier).to_ascii())
	client.put_data(("Content-Length: %d\n" % data.to_ascii().size()).to_ascii())
	client.put_data("Connection: close\n".to_ascii())
	client.put_data(("Content-Type: %s\n\n" % content_type).to_ascii())
	client.put_data(data.to_ascii())
