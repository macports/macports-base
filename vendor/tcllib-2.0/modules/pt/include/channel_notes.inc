[para]

Note here that the Parser Tools are based on Tcl 8.5+. In other words,
the channel argument is not restricted to files, sockets, etc. We have
the full power of [term {reflected channels}] available.

[para]

It should also be noted that the parser pulls the characters from the
input stream as it needs them. If a parser created by this package has
to be operated in a push aka event-driven manner it will be necessary
to go to Tcl 8.6+ and use the [package coroutine::auto] to wrap it
into a coroutine where [cmd read] is properly changed for
push-operation.
