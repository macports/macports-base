httpd: Operations Manual
===============================
[Back to Index](index.md)

The httpd module is designed to be an http server which is embeddable within another project.

1. When a reply socket is opened, the *connect* method is exercised.
2. The *connect* method then populates a dict with basic information such as the REMOTE_IP and the URI.
3. *connect* calls the Server's *dispatch* method with this new dict as a parameter.
4. *dispatch* returns with a dict describing the response to this request, or an empty list to indicate that this is an invalid request.
5. A new object is created to manage the reply.
    * If a **class** field is present in the dispatch dict, a new object will be of that class.
    * If no **class** was given, the new object will be of the class specified by the server's *reply_class* property.
6. If the field *mixin* is present and non-empty, the new reply object will mixin the class specified.
7. The server object will then call the reply object's *dispatch* process, with the complete reply description dict as a paramter.
8. The server adds the object to a list of objects it is tracking. If the reply object does not destroy itself within 2 minutes, the server will destroy it.

Once the *dispatch* method is called, it is the reply object's job to:

1. Parse the HTTP headers of the incoming request
2. Formulate a response
3. Transmit that response back across the request socket.
4. Destroy itself when finished.
5. On destruction, unregister itself from the server object.

The basic reply class perfoms the following:

1. Reads the HTTP years
2. Invokes the *content* class, which utilizes the *puts* method to populate an internal buffer.
3. Invokes the *output* class which will prepare reply headers and output the reply buffer to the request socket.
