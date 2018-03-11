#!/bin/sh

touch foo
chmod u+s,a+x foo

stat -f "perms: %p" foo

exec test $(stat -f %p foo) == 104755
