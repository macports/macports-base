#!/bin/bash


####
# PortIndex regen automation script.
# Created by Juan Manuel Palacios,
# e-mail: jmpp@opendarwin.org
# Date: 2005/10/2
####


PREFIX=/opt/local
PATH=/bin:/usr/bin:${PREFIX}/bin
DPORTS=${PREFIX}/var/db/dports/sources/rsync.rsync.opendarwin.org_dpupdate_dports
SU_OUT=/tmp/dpselfupdate.out
I_OUT=/tmp/portindex.out
FAILURES=/tmp/dp_index_failures.out
LOG=/tmp/regen.out
DATE=$(date +'%A %Y-%m-%d at %H:%M:%S')
MAILTO=portmgr@opendarwin.org
RSYNC=/Volumes/bigsrc/darwinports/portindex/


cd ${DPORTS}
#port -d selfupdate > ${SU_OUT} 2>&1
port -d sync > ${SU_OUT} 2>&1
if [ $? == 0 ]; then {
    rm -f PortIndex && portindex | tee ${I_OUT} | grep -A2 Failed > ${FAILURES}
    { cat ${FAILURES}; tail -n 5 ${I_OUT}; } > ${LOG}
    cp -f PortIndex ${RSYNC}
    cvs ci -F ${LOG} PortIndex
    cat ${LOG} | mail -s "Indexing Run on ${DATE}" ${MAILTO}
}
else
    cat ${SU_OUT} | mail -s "Indexing Failure on ${DATE}" ${MAILTO}
fi

rm -f ${SU_OUT} ${IO_UT} ${FAILURES} ${LOG}

exit 0

