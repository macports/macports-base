#!/bin/bash

####
# PortIndex regen automation script.
# Created by Juan Manuel Palacios,
# e-mail: jmpp@macports.org
# Updated by Paul Guyot, <pguyot@kallisys.net>
# Updated for svn by Daniel J. Luke <dluke@geeklair.net>
# $Id$
####

# Configuration
LOCKFILE=/tmp/.dp_svn_index_regen.lock
# ROOT directory, where everything is. This must exist.
ROOT=/Users/dluke/Projects/dp_svn_index_regen
# DP user.
DP_USER=dluke
# DP group.
DP_GROUP=staff
# e-mail address to spam in case of failure.
SPAM_LOVERS=macports-mgr@lists.macosforge.org,dluke@geeklair.net

# Other settings (probably don't need to be changed).
SVN_URL=https://svn.macports.org/repository/macports/trunk/
SVN_CONFIG_DIR=${ROOT}/svnconfig
# Where to checkout the source code. This gets created.
TREE=${ROOT}/source
# Where DP will install its world. This gets created.
PREFIX=${ROOT}/opt/local
# Where DP installs darwinports1.0. This gets created.
TCLPKG=${PREFIX}/lib/tcl
# Path.
PATH=${PREFIX}/bin:/bin:/usr/bin:/opt/local/bin
# Log for the e-mail in case of failure.
FAILURE_LOG=${ROOT}/failure.log
# Something went wrong.
FAILED=0
# Commit message.
COMMIT_MSG=${ROOT}/commit.msg
# The date.
DATE=$(date +'%A %Y-%m-%d at %H:%M:%S')

if [ ! -e $LOCKFILE ]; then
	touch $LOCKFILE
else
	echo "Index Regen lockfile found, is another index regen running?"
	exit 1
fi

# checkout if required, update otherwise.
if [ ! -d ${TREE} ]; then
		{ echo "SVN update failed, please check out a copy of DP into ${TREE}" >> $FAILURE_LOG ; FAILED=1 ; }
else
	cd ${TREE} && \
	svn -q --non-interactive --config-dir $SVN_CONFIG_DIR update > $FAILURE_LOG 2>&1 \
		|| { echo "SVN update failed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# (re)configure.
if [ $FAILED -eq 0 ]; then
	cd ${TREE}/base/ && \
	mkdir -p ${TCLPKG} && \
	./configure \
		--prefix=${PREFIX} \
		--with-tclpackage=${TCLPKG} \
		--with-install-user=${DP_USER} \
		--with-install-group=${DP_GROUP} > $FAILURE_LOG 2>&1 \
		|| { echo "./configure failed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# clean
# (cleaning is useful because we don't want the indexing to fail because dependencies aren't properly computed).
if [ $FAILED -eq 0 ]; then
	{ cd ${TREE}/base/ && \
	make clean > $FAILURE_LOG 2>&1 ; } \
		|| { echo "make clean failed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# (re)build
if [ $FAILED -eq 0 ]; then
	{ cd ${TREE}/base/ && \
	make > $FAILURE_LOG 2>&1 ; } \
		|| { echo "make failed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# (re)install
if [ $FAILED -eq 0 ]; then
	{ cd ${TREE}/base/ && \
	make install > $FAILURE_LOG 2>&1 ; } \
		|| { echo "make install failed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# (re)index
if [ $FAILED -eq 0 ]; then
	{ cd ${TREE}/dports/ && \
	${PREFIX}/bin/portindex > $FAILURE_LOG 2>&1 ; } \
		|| { echo "portindex failed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# check all ports were indexed.
if [ $FAILED -eq 0 ]; then
	grep Failed $FAILURE_LOG \
		&& { echo "some ports couldn\'t be indexed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# commit the file if and only if all ports were successfully indexed.
if [ $FAILED -eq 0 ]; then
	# Use the last 5 lines of the log for the commit message.
	tail -n 5 $FAILURE_LOG > $COMMIT_MSG
	
	# Actually commit the file.
	{ cd ${TREE}/dports/ && \
	svn --config-dir $SVN_CONFIG_DIR commit -F $COMMIT_MSG PortIndex > $FAILURE_LOG 2>&1 ; } \
		|| { echo "SVN commit failed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# spam if something went wrong.
if [ $FAILED -ne 0 ]; then
	mail -s "AutoIndex Failure on ${DATE}" $SPAM_LOVERS < $FAILURE_LOG
else
	# trash log files
	rm -f $COMMIT_MSG $FAILURE_LOG
fi

rm -f $LOCKFILE
