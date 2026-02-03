#!/bin/sh

if [ -z "$CODESIGN_ID" ]; then
    if [ -f "${HOME}/.macports/codesign_id" ]; then
        CODESIGN_ID=`cat "${HOME}/.macports/codesign_id"`
    else
        echo "No codesigning identity specified"
        exit 1
    fi
fi

if [ `id -u` -eq 0 -a -n "$SUDO_USER" ]; then
    SUDO="sudo -u $SUDO_USER"
else
    SUDO=
fi

for f in "$@"; do
    if [ -n "$SUDO" ]; then
        DIR=`dirname "$f"`
        FILE_OWNER=`stat -f %u "$f"`
        DIR_OWNER=`stat -f %u "$DIR"`
        chown "$SUDO_USER" "$f" "$DIR"
    fi

    while ! $SUDO /usr/bin/codesign --sign "$CODESIGN_ID" --identifier=org.macports.base --options=runtime --timestamp --verbose "$f"
    do
        sleep 1
    done
    if [ -n "$SUDO" ]; then
        chown "$FILE_OWNER" "$f"
        chown "$DIR_OWNER" "$DIR"
    fi

    pkgindex=$(dirname "$f")/pkgIndex.tcl
    if [ -e "$pkgindex" ]; then
        touch "$pkgindex"
    fi
done
