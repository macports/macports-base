# global port routines
package provide portconfigure 1.0
package require portutil 1.0

register_target configure portconfigure::main main fetch extract checksum patch
namespace eval portconfigure {
	variable options
}

# define globals
globals portconfigure::options

# define options
options portconfigure::options configure configure_args gnu_configure xmkmf use_imake use_automake automake_env use_autoconf use_libtool

proc portconfigure::main {args} {
	global portname workdir

	return 0
}
