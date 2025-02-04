[comment {-*- mode: tcl ; fill-column: 90 -*-}]

This section demonstrates how to convert from any kind of bit-mapped flags provided by an
external library to lists of Tcl strings, and the converse.

[list_begin enumerated]

[enum] For all that this is a part of how to
[sectref {Using External Libraries} {Use External Libraries}], for the demonstratation
only the basics are needed.

[enum][vset base][example {
    # http://man7.org/linux/man-pages/man7/inotify.7.html
    
    package require critcl::bitmap

    # critcl::cheaders - n/a, header is in system directories
    critcl::include sys/inotify.h
    
    critcl::bitmap::def tcl_inotify_events {
	accessed       IN_ACCESS
	all            IN_ALL_EVENTS
	attribute      IN_ATTRIB
	closed         IN_CLOSE
	closed-nowrite IN_CLOSE_NOWRITE
	closed-write   IN_CLOSE_WRITE
	created        IN_CREATE
	deleted        IN_DELETE
	deleted-self   IN_DELETE_SELF
	dir-only       IN_ONLYDIR
	dont-follow    IN_DONT_FOLLOW
	modified       IN_MODIFY
	move           IN_MOVE
	moved-from     IN_MOVED_FROM
	moved-self     IN_MOVE_SELF
	moved-to       IN_MOVED_TO
	oneshot        IN_ONESHOT
	open           IN_OPEN
	overflow       IN_Q_OVERFLOW
	unmount        IN_UNMOUNT
    } {
	all closed move oneshot
    }
    
    # encode: flag set to int
    critcl::cproc encode {tcl_inotify_events e} int {
	return e;
    }

    # decode: int to flag set
    critcl::cproc decode {int e} tcl_inotify_events {
	return e;
    }

}][vset rebuild]

[enum] The map converts between lists of the Tcl level strings listed on the left side to
the bit-union of the C values on the right side, and the reverse.

[para] It is noted that the four strings [const all], [const closed], [const move], and
[const oneshot] cannot be converted from C flags to list of strings, only from list to
bits.

[enum] It automatically generates [cmd critcl::argtype] and [cmd critcl::resulttype]
definitions.

[enum] [emph Attention] Like the default values for [cmd cproc] arguments, and the results
for [cmd cconst] definitions the values on the right side have to be proper C
rvalues. They have to match C type [type int].

[para] In other words, it is perfectly ok to use the symbolic names provided by the header
file of the external library. As shown.

[list_end]

[para] Packages: [term critcl::bitmap]
