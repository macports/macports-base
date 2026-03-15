
[opt_def -mode [arg mode]]

This option specifies the mode the object is in. It is optional and
defaults to [const active] mode. The two possible modes are:

[list_begin definitions]
[def [const active]]

In this mode the two options [option -host] and [option -port] are
relevant and specify the host and TCP port the object has to connect
to. The host is given by either name or IP address.

[def [const passive]]

In this mode the option [option -host] has no relevance and is ignored
should it be configured.

The only option the object needs is [option -port], and it specifies
the TCP port on which the listening socket is opened to await the
connection from the partner.

[list_end]

[opt_def -host [arg hostname-or-ipaddr]]

This option specifies the host to connect to in [term active] mode,
either by name or ip-address. An object configured for [term passive]
mode ignores this option.

[opt_def -port [arg int]]

For [term active] mode this option specifies the port the object is
expected to connect to. For [term passive] mode however it is the port
where the object creates the listening socket waiting for a
connection. It defaults to [const 0], which allows the OS to choose
the actual port to listen on.

[opt_def -socketcmd [arg command]]

This option allows the user to specify which command to use to open a
socket. The default is to use the builtin [cmd ::socket]. Any
compatible with that command is allowed.

[para]

The envisioned main use is the specfication of [cmd tls::socket]. I.e.
this option allows the creation of secure transfer channels, without
making this package explicitly dependent on the [package tls] package.

[para]

See also section [sectref {Secure connections}].


[opt_def -encoding encodingname]
[opt_def -eofchar eofspec]
[opt_def -translation transspec]

These options are the same as are recognized by the builtin command
[cmd fconfigure]. They provide the configuration to be set for the
channel between the two partners after it has been established, but
before the callback is invoked (See method [method connect]).
