#!/bin/sh
args=`getopt c: $*`
if [ $? -ne 0 ] || [ $# -eq 0 ]; then
	echo "Usage: $0 [-c <tcl directory>] <action> <options>"
	echo "Actions:"
	echo "    compile <sources>"
	echo "    link <library name> <object files>"
	echo "    shlibname <library name>"
	echo "    installdir"
	exit 2
fi

set -- $args
for i; do
	case "$i"
	in
		-c)
			tclDir=$2; shift; shift;;
		link|compile|installdir|shlibname)
			shift; action=$1; shift; args=$*; break;;
	esac
done

if [ "$tclDir" = "" ]; then
	for i in /usr/lib/ /usr/local/lib /usr/pkg/lib /System/Library/Tcl/8.3
	do
		if [ -f $i/tclConfig.sh ]; then
			tclConfig=$i/tclConfig.sh
		fi
	done
else
	tclConfig=$tclDir/tclConfig.sh
	if [ ! -f $tclConfig ]; then
		echo "$tclConfig: No such file or directory"
		exit 3
	fi
fi

if [ "$tclConfig" = "" ]; then
	echo "Could not find tclConfig.sh"
	exit 3
fi

. $tclConfig

case $action
in
	compile)
		if [ -f $TCL_PREFIX/include/tcl$TCL_VERSION/tcl.h ]; then
			tclInc=-I$TCL_PREFIX/include/tcl$TCL_VERSION
		elif [ -f $TCL_PREFIX/include/tcl.h ]; then
			tclInc=-I$TCL_PREFIX/include/
		else
			echo "Can not find tcl includes"
			exit 3
		fi
		tclCc="$TCL_CC -c $TCL_CFLAGS_OPTIMIZE $tclInc $*"
		echo "$tclCc"
		$tclCc
		break;;
	link)
		libName=$1; shift; objFiles=$*
		tclLd="$TCL_SHLIB_LD $tclLd $objFiles -o $libName$TCL_SHLIB_SUFFIX $TCL_LIB_SPEC"
		tclLdClean=`echo $tclLd | sed s/\\\${TCL_CC}/"$TCL_CC"/g | sed s/\\\${[A-Za-z_]*}//g`
		echo "$tclLdClean"
		$tclLdClean
		exit 0;;
	shlibname)
		echo "$1$TCL_SHLIB_SUFFIX"
		exit 0;;
	installdir)
		if [ `uname -s` = "Darwin" ]; then
			if [ -d /System/Library/Tcl/$TCL_VERSION ]; then
				echo "/System/Library/Tcl/$TCL_VERSION/darwinports1.0"
				exit 0
			fi
			echo NO
		fi
		for i in /usr/lib /usr/pkg/lib /usr/local/lib; do
			if [ -d $i/tcl$TCL_VERSION ]; then
				echo $i/tcl$TCL_VERSION/darwinports1.0
				exit 0
			fi
		done
		exit 3;;
esac
