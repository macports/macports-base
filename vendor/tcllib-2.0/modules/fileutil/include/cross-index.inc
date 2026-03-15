[example {
	/sys/class/tty/tty0 --> ../../dev/tty0
	/sys/class/tty/tty1 --> ../../dev/tty1
	/sys/class/tty/tty2 --> ../../dev/tty1

	/sys/dev/tty0/bus
	/sys/dev/tty0/subsystem --> ../../class/tty
	/sys/dev/tty1/bus
	/sys/dev/tty1/subsystem --> ../../class/tty
	/sys/dev/tty2/bus
	/sys/dev/tty2/subsystem --> ../../class/tty
}]
