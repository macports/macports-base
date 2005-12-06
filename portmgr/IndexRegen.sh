#!/bin/bash

####
# PortIndex regen automation script.
# Created by Juan Manuel Palacios,
# e-mail: jmpp@opendarwin.org
# Updated by Paul Guyot, <pguyot@kallisys.net>
# $Id: IndexRegen.sh,v 1.1.2.2 2005/12/06 21:37:01 jmpp Exp $
####

# Configuration
# ROOT directory, where everything is. This must exist.
ROOT=/Users/pguyot/dp-portindex
# SSH key. This must exist.
SSH_KEY=${ROOT}/id_dsa
# DP user.
DP_USER=pguyot
# DP group.
DP_GROUP=darwinports
# CVS user.
CVS_USER=pguyot
# e-mail address to spam in case of failure.
SPAM_LOVERS=portmgr@opendarwin.org

# Other settings (probably don't need to be changed).
# CVS root.
CVS_ROOT=:ext:${CVS_USER}@cvs.opendarwin.org:/Volumes/src/cvs/od
#CVS_ROOT=/Volumes/src/cvs/od # <-- direct access on the same box.
# CVS module.
CVS_MODULE=darwinports
# Wrapper. This gets created.
SSH_WRAPPER=${ROOT}/ssh_wrapper
# Where to checkout the source code. This gets created.
TREE=${ROOT}/source
# Where DP will install its world. This gets created.
PREFIX=${ROOT}/opt/local
# Where DP installs darwinports1.0. This gets created.
TCLPKG=${PREFIX}/lib/tcl
# Path.
PATH=${PREFIX}/bin:/bin:/usr/bin
# Log for the e-mail in case of failure.
FAILURE_LOG=${ROOT}/failure.log
# Something went wrong.
FAILED=0
# Commit message.
COMMIT_MSG=${ROOT}/commit.msg
# The date.
DATE=$(date +'%A %Y-%m-%d at %H:%M:%S')

# Create the SSH wrapper if it doesn't exist (comment this for -d /Volumes...)
if [ ! -e $SSH_KEY ]; then
	echo "Key doesn't exist. The script is configured to find the SSH key at:"
	echo "${SSH_KEY}"
	exit 1
fi

# Create the SSH wrapper if it doesn't exist  (comment this for -d /Volumes...)
if [ ! -x $SSH_WRAPPER ]; then
	echo "#!/bin/bash" > $SSH_WRAPPER && \
	echo "/usr/bin/ssh -i ${SSH_KEY} \$*" >> $SSH_WRAPPER 1 && \
	chmod +x $SSH_WRAPPER \
		|| { echo "Creation of wrapper failed" ; exit 1 ; }
fi

# checkout if required, update otherwise.
if [ ! -d ${TREE} ]; then
	mkdir -p ${TREE} && \
	cd ${TREE} && \
	CVS_RSH=${SSH_WRAPPER} cvs -q -d $CVS_ROOT co darwinports > $FAILURE_LOG 2>&1 \
		|| { echo "CVS checkout failed" >> $FAILURE_LOG ; FAILED=1 ; }
else
	cd ${TREE}/${CVS_MODULE} && \
	CVS_RSH=${SSH_WRAPPER} cvs -q update -dP > $FAILURE_LOG 2>&1 \
		|| { echo "CVS update failed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# (re)configure.
if [ $FAILED -eq 0 ]; then
	cd ${TREE}/${CVS_MODULE}/base/ && \
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
	{ cd ${TREE}/${CVS_MODULE}/base/ && \
	make clean > $FAILURE_LOG 2>&1 ; } \
		|| { echo "make clean failed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# (re)build
if [ $FAILED -eq 0 ]; then
	{ cd ${TREE}/${CVS_MODULE}/base/ && \
	make > $FAILURE_LOG 2>&1 ; } \
		|| { echo "make failed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# (re)install
if [ $FAILED -eq 0 ]; then
	{ cd ${TREE}/${CVS_MODULE}/base/ && \
	make install > $FAILURE_LOG 2>&1 ; } \
		|| { echo "make install failed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# (re)index
if [ $FAILED -eq 0 ]; then
	{ cd ${TREE}/${CVS_MODULE}/dports/ && \
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
	{ cd ${TREE}/${CVS_MODULE}/dports/ && \
	CVS_RSH=${SSH_WRAPPER} cvs commit -F $COMMIT_MSG PortIndex > $FAILURE_LOG 2>&1 ; } \
		|| { echo "cvs commit failed" >> $FAILURE_LOG ; FAILED=1 ; }
fi

# spam if something went wrong.
if [ $FAILED -ne 0 ]; then
	mail -s "AutoIndex Failure on ${DATE}" $SPAM_LOVERS < $FAILURE_LOG
else
	# trash log files
	rm -f $COMMIT_MSG $FAILURE_LOG
fi

