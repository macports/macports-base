
[opt_def -channel  [arg handle]]

This option specifies that the destination of the data is a channel,
and its associated argument is the handle of the channel to write the
received data to.

[opt_def -file     [arg path]]

This option specifies that the destination of the data is a file, and
its associated argument is the path of the file to write the received
data to.

[opt_def -variable [arg varname]]

This option specifies that the destination of the data is a variable,
and its associated argument contains the name of the variable to write
the received data to. The variable is assumed to be global or
namespaced, anchored at the global namespace.

[opt_def -progress [arg command]]

This option, if specified, defines a command to be invoked for each
chunk of bytes received, allowing the user to monitor the progress of
the reception of the data. The callback is always invoked with one
additional argument, the number of bytes received so far.

