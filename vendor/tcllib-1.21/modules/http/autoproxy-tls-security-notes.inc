[section {TLS Security Considerations}]

[para][emph Note] This section only applies if TLS support is provided
by the [package TLS] package.

It does not apply when [package autoproxy] was configured to use some
other package which can provide the same (i.e [package twapi]), via
the [option -tls_package] configuration option.

[include ../common-text/tls-security-text.inc]
