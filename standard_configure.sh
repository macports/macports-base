#!/bin/sh

# This is how we run configure when building the MacPorts installer packages.
# If you don't want a custom build, this is probably how you should run it too.
#
# If you want to use a different prefix, or any other additional configure
# arguments, you can supply them as arguments when invoking this script.
#
# Some environment variables are also supported for altering the defaults:
#
# ARCHFLAGS
#   -arch flags with which to build. If not specified, it is contructed from
#   ARCHS. See also UNIVERSAL.
#
# ARCHS
#   The list of architectures for which to build. If you prefer, specify the
#   -arch flags in ARCHFLAGS instead. See also UNIVERSAL. To disable the use of
#   -arch flags, use "ARCHS=".
#
# CC
#   The C compiler executable.
#
# CFLAGS
#   Additional C compiler flags which are appended to the defaults.
#
# LDFLAGS
#   Additional linker flags which are appended to the defaults.
#
# MACOSX_DEPLOYMENT_TARGET
#   The minimum macOS version on which the compiled libraries and programs are
#   intended to run. It has not been tested whether building for an earlier
#   deployment target results in all aspects of MacPorts functioning correctly
#   on earlier macOS versions, so changing the value of this variable is not
#   recommended except to perform such testing. In addition, some values that
#   vary based on macOS version are recorded in text files like macports.conf,
#   macports_autoconf.tcl and port_autoconf.tcl, so they must be generated on
#   the same major version of macOS as the one on which they will be used.
#
# OPTFLAGS
#   Compiler optimization flags.
#
# SDKPATH
#   The path to the macOS SDK with which to build.
#
# UNIVERSAL
#   Whether the default ARCHS are universal (yes/no).

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MACPORTS_VERSION=$(cat "$SCRIPT_DIR/config/macports_version")
CONFIGURE=$SCRIPT_DIR/configure
DEFAULT_CFLAGS=-pipe
DEFAULT_LDFLAGS=
PATH=/usr/bin:/bin:/usr/sbin:/sbin

SYSTEM_NAME=$(uname -s)
if [ "$SYSTEM_NAME" = "Darwin" ]; then
    DEFAULT_LDFLAGS="$DEFAULT_LDFLAGS -Wl,-headerpad_max_install_names"
    MACOS_VERSION_MAJOR=$(sw_vers -productVersion | cut -d. -f1-2)
    : "${MACOSX_DEPLOYMENT_TARGET=$MACOS_VERSION_MAJOR}"
    case $MACOS_VERSION_MAJOR in
        10.[0123])
            echo "MacPorts $MACPORTS_VERSION requires Mac OS X 10.4 or later." 1>&2
            exit 1
            ;;
        10.4)
            : "${CC=/usr/bin/gcc-4.0}"
            : "${SDKPATH=/Developer/SDKs/MacOSX10.4u.sdk}"
            ;;
        10.5)
            : "${CC=/usr/bin/gcc-4.2}"
            ;;
        *)
            : "${CC=/usr/bin/clang}"
            ;;
    esac
    case $MACOS_VERSION_MAJOR in
        10.[456])
            : "${UNIVERSAL=yes}"
            ;;
        *)
            : "${UNIVERSAL=no}"
            ;;
    esac
    case $MACOS_VERSION_MAJOR in
        10.[45])
            if [ "$UNIVERSAL" = "yes" ]; then
                : "${ARCHS=ppc i386}"
            else
                if [ "$(uname -m)" = "Power Macintosh" ]; then
                    : "${ARCHS=ppc}"
                else
                    : "${ARCHS=i386}"
                fi
            fi
            ;;
        *)
            if [ "$UNIVERSAL" = "yes" ]; then
                : "${ARCHS=x86_64 i386}"
            else
                if [ "$(sysctl -n hw.cpu64bit_capable)" = "1" ]; then
                    : "${ARCHS=x86_64}"
                else
                    : "${ARCHS=i386}"
                fi
            fi
            ;;
    esac
fi

if [ -z "${ARCHFLAGS-}" ]; then
    for A in ${ARCHS-}; do
        ARCHFLAGS="${ARCHFLAGS-} -arch $A"
    done
    ARCHFLAGS="${ARCHFLAGS# }"
fi

: "${CC=cc}"
: "${MACOSX_DEPLOYMENT_TARGET=}"
: "${OPTFLAGS=-Os}"

CFLAGS="$DEFAULT_CFLAGS${OPTFLAGS:+ $OPTFLAGS}${ARCHFLAGS:+ $ARCHFLAGS}${SDKPATH:+ -isysroot$SDKPATH}${CFLAGS:+ $CFLAGS}"
CFLAGS="${CFLAGS# }"
LDFLAGS="$DEFAULT_LDFLAGS${ARCHFLAGS:+ $ARCHFLAGS}${SDKPATH:+ -Wl,-syslibroot,$SDKPATH}${LDFLAGS:+ $LDFLAGS}"
LDFLAGS="${LDFLAGS# }"

echo "Configuring MacPorts $MACPORTS_VERSION with the following environment:"
for VAR in CC CFLAGS LDFLAGS MACOSX_DEPLOYMENT_TARGET PATH; do
    echo "$VAR=\"${!VAR}\""
done

env -i \
    CC="$CC" \
    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS" \
    MACOSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET" \
    PATH="$PATH" \
    "$CONFIGURE" \
    --enable-readline \
    "$@"
