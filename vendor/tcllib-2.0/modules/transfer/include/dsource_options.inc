[opt_def -string   [arg text]]

This option specifies that the source of the data is an immediate
string, and its associated argument contains the string in question.

[opt_def -channel  [arg handle]]

This option specifies that the source of the data is a channel, and
its associated argument is the handle of the channel containing the
data.

[opt_def -file     [arg path]]

This option specifies that the source of the data is a file, and its
associated argument is the path of the file containing the data.

[opt_def -variable [arg varname]]

This option specifies that the source of the data is a string stored
in a variable, and its associated argument contains the name of the
variable in question. The variable is assumed to be global or
namespaced, anchored at the global namespace.

[opt_def -size     [arg int]]

This option specifies the size of the data transfer. It is optional
and defaults to -1. This value, and any other value less than zero
signals to transfer all the data from the source.

[opt_def -progress [arg command]]

This option, if specified, defines a command to be invoked for each
chunk of bytes transmitted, allowing the user to monitor the progress
of the transmission of the data. The callback is always invoked with
one additional argument, the number of bytes transmitted so far.
