[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] Use the command [cmd critcl::cdata] to create a command taking no arguments and
returning a constant ByteArray value.

[para] [example {
    # P5 3 3 255 \n ...
    critcl::cdata cross3x3pgm {
	80 52 32 51 32 51 32 50 53 53 10
	0   255 0
	255 255 255
	0   255 0
    }
}]

[list_end]
