#!/bin/sh

# This is how we run configure when building binary packages (more or less,
# minus architecture selection). If you don't want a custom build, this
# is probably how you should run it too.
env PATH=/usr/bin:/bin:/usr/sbin:/sbin CFLAGS="-pipe -Os" ./configure --enable-readline "$@"

# If you want to use a different prefix, add this to the above:
# --prefix=/some/path --with-applications-dir=/some/path/Applications
