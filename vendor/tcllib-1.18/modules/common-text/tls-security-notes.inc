
[section {TLS Security Considerations}]

This package uses the [package TLS] package to handle the security
for [const https] urls and other socket connections.

[para] Policy decisions like the set of protocols to support and what
ciphers to use are not the responsibility of [package TLS], nor of
this package itself however.

Such decisions are the responsibility of whichever application is
using the package, and are likely influenced by the set of servers
the application will talk to as well.

[para] For example, in light of the recent
[uri http://googleonlinesecurity.blogspot.co.uk/2014/10/this-poodle-bites-exploiting-ssl-30.html \
{POODLE attack}] discovered by Google many servers will disable support
for the SSLv3 protocol.

To handle this change the applications using [package TLS] must be
patched, and not this package, nor [package TLS] itself.

Such a patch may be as simple as generally activating [const tls1]
support, as shown in the example below.

[example {
    package require tls
    tls::init -tls1 1 ;# forcibly activate support for the TLS1 protocol

    ... your own application code ...
}]
