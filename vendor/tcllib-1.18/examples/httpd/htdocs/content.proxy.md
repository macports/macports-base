httpd::content::proxy
=============
Back to: [Index](index.md) | [Package httpd::content](content.md)

The proxy handler farms out the generation of content to an external process running
on a known port. The external process is assumed to be a proxy server, and it is the job
of this object to transform the query as received into a form that is understood by
the external server.

To implement a proxy handler, replace **proxy_info** with one that will return a list
containing the following:

    PROXYHOST PROXYPORT PROXYURI
    
* PROXYHOST - The hostname or IP address of the server running the process
* PROXYPORT - The port to connect to
* PROXYURI - The replacement GET/POST/etc request to make to the external process.

The **proxy_info** method also makes a handly place to spawn a locally hosted process on demand.
For an example of this, see the [docserver.tcl](docserver.tcl) Example.