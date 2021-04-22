[section {Class ::httpd::content}]

The httpd module includes several ready to use implementations of content mixins
for common use cases. Options are passed in to the [cmd add_uri] method of the server.

[section {Class ::httpd::content.cgi}]

An implementation to relay requests to process which will accept post data
streamed in vie stdin, and sent a reply streamed to stdout.

[list_begin definitions]
[call method cgi_info]

Mandatory method to be replaced by the end user. If needed, activates the
process to proxy, and then returns a list of three values:

[arg exec] - The arguments to send to exec to fire off the responding process, minus the stdin/stdout redirection.

[list_end]

[section {Class ::httpd::content.file}]

An implementation to deliver files from the local file system.

[list_begin definitions]

[call option [cmd path]]

The root directory on the local file system to be exposed via http.

[call option [cmd prefix]]

The prefix of the URI portion to ignore when calculating relative file paths.
[list_end]

[section {Class ::httpd::content.proxy}]

An implementation to relay requests to another HTTP server, and relay
the results back across the request channel.

[list_begin definitions]
[call method proxy_info]

Mandatory method to be replaced by the end user. If needed, activates the
process to proxy, and then returns a list of three values:

[arg proxyhost] - The hostname where the proxy is located

[arg proxyport] - The port to connect to

[arg proxyscript] - A pre-amble block of text to send prior to the mirrored request

[list_end]

[section {Class ::httpd::content.scgi}]

An implementation to relay requests to a server listening on a socket
expecting SCGI encoded requests, and relay
the results back across the request channel.

[list_begin definitions]
[call method scgi_info]

Mandatory method to be replaced by the end user. If needed, activates the
process to proxy, and then returns a list of three values:

[arg scgihost] - The hostname where the scgi listener is located

[arg scgiport] - The port to connect to

[arg scgiscript] - The contents of the [arg SCRIPT_NAME] header to be sent

[list_end]

[section {Class ::httpd::content.websocket}]

A placeholder for a future implementation to manage requests that can expect to be
promoted to a Websocket. Currently it is an empty class.

[section {SCGI Server Functions}]

The HTTP module also provides an SCGI server implementation, as well as an HTTP
implementation. To use the SCGI functions, create an object of the [cmd http::server.scgi]
class instead of the [cmd http::server] class.

[section {Class ::httpd::reply.scgi}]

An modified [cmd http::reply] implementation that understands how to deal with
netstring encoded headers.

[section {Class ::httpd::server.scgi}]

A modified [cmd http::server] which is tailored to replying to request according to
the SCGI standard instead of the HTTP standard.
