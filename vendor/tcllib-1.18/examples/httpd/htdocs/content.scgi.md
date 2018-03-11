httpd::content::scgi
=============
Back to: [Index](index.md) | [Package httpd::content](content.md)

The SCGI handler farms out the generation of content to an external process
running at a known port. Because this process is persistent, the SCGI system
avoids the overhead of spawning and spooling up an external process with
every page view.

To implement an SCGI handler, replace the **scgi_info** method with one
that will return a list containing the following:

   SCGIHOST SCGIPORT SCGISCRIPT
   
* SCGIHOST - The hostname or IP address of the server running the process
* SCGIPORT - The port to connect to
* SCGISCRIPT - The SCGISCRIPT parameter which will be passed to the external process via headers.

The **scgi_info** method also makes a handly place to spawn a locally hosted process on demand.
For an example of this, see the [docserver.tcl](docserver.tcl) Example.