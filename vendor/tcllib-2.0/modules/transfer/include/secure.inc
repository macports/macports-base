[section {Secure connections}]

One way to secure connections made by objects of this package is to
require the package [package tls] and then configure the option
[option -socketcmd] to force the use of command [cmd tls::socket] to
open the socket.

[example_begin]
    # Load and initialize tls
    package require tls
    tls::init -cafile /path/to/ca/cert -keyfile ...

    # Create a connector with secure socket setup,
    [vset OBJCREATE] -socketcmd tls::socket ...
    ...
[example_end]

[include ../../common-text/tls-security-notes.inc]
