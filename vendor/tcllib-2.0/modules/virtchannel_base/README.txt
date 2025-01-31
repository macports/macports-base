null, zero, fifo, memchan, fifo2

	Re-implementations of Memchan's channel types.

random

	Semi re-implementation of a Memchan channel type.
	"Random" byte generator, simple feedback register.
	Memchan uses ISAAC (http://burtleburtle.net/bob/rand/isaacafa.html).

string, variable

	Variants of 'memchan', with fixed content, and the content
	factored out to a namespaced variable, respectively.

randomseed

	Support to generate and combine seed lists for the
	random channel, using semi-random sources in Tcl.

halfpipe

	Half channel, simpler callback API. fifo2 is build on top this
	basic block.

textwindow

	Channel attaches to text widget to write data into.

cat

	Concatenation channel, delivering the data from 1 or more
	channels, one after the other.

facade

	A wrapper around any other channel. Mainly for debugging,
	allowing a developer to observe the activity on the wrapped
	channel.

std

	Unification of stdin and stdout into a single read/write
	channel
