[section {Class ::httpd::server}]

This class is the root object of the webserver. It is responsible
for opening the socket and providing the initial connection negotiation.

[list_begin definitions]
[call constructor ?port [opt port]? ?myaddr [opt ipaddr]|all? ?server_string [opt string]? ?server_name [opt string]?]
Build a new server object. [opt port] is the port to listen on

[call method [cmd add_uri] [arg pattern] [arg dict]]
Set the hander for a URI pattern. Information given in the [arg dict] is stored
in the data structure the [cmd dispatch] method uses. If a field called
[arg mixin] is given, that class will be mixed into the reply object immediately
after construction.

[call method [cmd connect] [arg sock] [arg ip] [arg port]]

Reply to an open socket. This method builds a coroutine to manage the remainder
of the connection. The coroutine's operations are driven by the [cmd Connect] method.

[call method [cmd Connect] [arg uuid] [arg sock] [arg ip]]

This method reads HTTP headers, and then consults the [cmd dispatch] method to
determine if the request is valid, and/or what kind of reply to generate. Under
normal cases, an object of class [cmd ::http::reply] is created.

Fields the server are looking for in particular are:

class: A class to use instead of the server's own [arg reply_class]

mixin: A class to be mixed into the new object after construction.

All other fields are passed along to the [cmd http_info] structure of the
reply object.

After the class is created and the mixin is mixed in, the server invokes the
reply objects [cmd dispatch] method. This action passes control of the socket to
the reply object. The reply object manages the rest of the transaction, including
closing the socket.

[call method [cmd counter] [arg which]]

Increment an internal counter.

[call method [cmd CheckTimeout]]

Check open connections for a time out event.

[call method [cmd dispatch] [arg header_dict]]

Given a key/value list of information, return a data structure describing how
the server should reply.

[call method [cmd log] [arg args]]

Log an event. The input for args is free form. This method is intended
to be replaced by the user, and is a noop for a stock http::server object.

[call method [cmd port_listening]]

Return the actual port that httpd is listening on.

[call method [cmd PrefixNormalize] [arg prefix]]

For the stock version, trim trailing /'s and *'s from a prefix. This
method can be replaced by the end user to perform any other transformations
needed for the application.

[call method [cmd start]]

Open the socket listener.

[call method [cmd stop]]

Shut off the socket listener, and destroy any pending replies.

[call method [cmd template] [arg page]]

Return a template for the string [arg page]

[call method [cmd TemplateSearch] [arg page]]

Perform a search for the template that best matches [arg page]. This
can include local file searches, in-memory structures, or even
database lookups. The stock implementation simply looks for files
with a .tml or .html extension in the [opt doc_root] directory.

[call method [cmd Validate_Connection] [arg sock] [arg ip]]


Given a socket and an ip address, return true if this connection should
be terminated, or false if it should be allowed to continue. The stock
implementation always returns 0. This is intended for applications to
be able to implement black lists and/or provide security based on IP
address.

[list_end]
