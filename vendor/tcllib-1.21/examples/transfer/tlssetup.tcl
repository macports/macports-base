# Initialization of TLS for the example applications.

tls::init \
    -keyfile  $selfdir/certs/${type}.key \
    -certfile $selfdir/certs/${type}.crt \
    -cafile   $selfdir/certs/ca.crt \
    -ssl2 1    \
    -ssl3 1    \
    -tls1 0    \
    -require 1 \
    -password PWD \
    -command  CMD

proc PWD {args} {
    puts P\t($args)
    return $type
}

proc CMD {option args} {
    switch -- $option {
	error {
	    return 1
	}
	info {
	    foreach {chan major minor message} $args break
	    puts "@ $chan ($major, $minor) = $message"
	    return 1
	}
	verify {
	    foreach {chan depth cert rc err} $args break
	    array set c $cert
	    puts CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
	    puts "C $chan $depth/$rc = $err"
	    parray c
	    puts ____________________________________________________________

	    # Code to perform additional checks on the cert goes here.

	    # always accept, even if rc is not 1 application
	    # connection handler will determine what to do

	    return 1
	}
	default  {
	    return -code error "bad option \"$option\": must be one of error, info, or verify"
	}
    }
    return
}
