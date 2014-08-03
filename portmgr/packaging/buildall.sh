#!/bin/sh

# Author: Jordan K. Hubbard
# Date: 2004/12/10
#
# Declare all the various shell functions which do the heavy lifting.
# If you want to see the main body of this script, go to the end of the file.

# What we want to call the base chroot images
CHROOTBASE=chrootbase.sparseimage
DPORTSCACHE=dportscache.sparseimage
FSTYPE=HFSX

# Some conservative (and large) defaults.
BASE_PADDING=16000000
DPORTSCACHE_SIZE=65536M

# deal with fatal errors
bomb() {
	echo "Error: $*"
	echo "BASEDEV=${BASEDEV} DPORTSDEV=${DPORTSDEV}"
	exit 1
}

# Everything we need to create the base chroot disk image (populated from host)
mkchrootbase() {
	if [ -f ${CHROOTBASE} ]; then
		echo "Using existing ${CHROOTBASE} for efficiency"
	else
		dir=$1
		mkdir -p $dir

		# Add to this list as you find minimum dependencies DP really needs.
		chrootfiles="bin sbin etc tmp var/log var/spool var/run var/tmp var/db private/etc private/tmp private/var dev/null usr Developer System/Library Library"

		echo "Calculating chroot base image size..."
		# start with this size to account for other overhead
		sz=${BASE_PADDING}
		if [ "`uname -r|tr -d .`" -ge 800 ]; then
			# hack-around for Tiger
			sz=$((sz + 8000000))
		else
			for i in $chrootfiles; do
				mysz=`cd /; du -sk $i |awk '{print $1}'`
				sz=$(($sz + $mysz))
			done
		fi
		echo "Creating bootstrap disk image of ${sz}K bytes"
		hdiutil create -size ${sz}k -fs ${FSTYPE} -volname base ${CHROOTBASE} > /dev/null
		BASEDEV=`hdiutil attach ${CHROOTBASE} -mountpoint $dir -noverify 2>&1 | awk '/dev/ {if (x == 0) {print $1; x = 1}}'`
		echo "Image attached as $BASEDEV"
		echo "Copying chroot files into bootstrap disk image"
		for i in $chrootfiles; do
			pax -pe -rw /$i $dir 2>/dev/null
			# special case for pax
			cp /bin/pax $dir/bin/pax
		done
		# special case nukes to prevent builder pollution
		rm -rf $dir/usr/X11R6 $dir/etc/X11
		rm -rf $dir/opt/local $dir/etc/ports
		# If there are any work-arounds, apply them now
		if [ -f chroot-fixups.tar.gz ]; then
			echo "Found chroot-fixups.tar.gz - applying to new chroot"
			tar xpzf chroot-fixups.tar.gz -C $dir
		fi
		if [ -f darwinports.tar.gz ]; then
			echo "Found darwinports.tar.gz - copying into chroot"
			tar -xpzf darwinports.tar.gz -C $dir
		elif [ -d darwinports ]; then
			pax -rw darwinports $dir
		else
			echo "no darwinports.tar.gz or darwinports directory found - please fix this and try again."
			exit 1
		fi
		bootstrapdports $dir
	fi
	if [ -f ${DPORTSCACHE} ]; then
		echo "Using existing ${DPORTSCACHE} for efficiency"
	else
		echo "Creating dports cache of size ${DPORTSCACHE_SIZE}"
		hdiutil create -size ${DPORTSCACHE_SIZE} -fs ${FSTYPE} -volname distfiles ${DPORTSCACHE} > /dev/null
		DPORTSDEV=`hdiutil attach ${DPORTSCACHE} -mountpoint $dir -noverify 2>&1 | awk '/dev/ {if (x == 0) {print $1; x = 1}}'`
		mkdir -p $dir/distfiles
		mkdir -p $dir/packages/darwin/powerpc
		hdiutil detach $DPORTSDEV -force >& /dev/null && DPORTSDEV=""
	fi
}

bootstrapdports() {
	dir=$1
	cat > $dir/bootstrap.sh << EOF
#!/bin/sh
cd darwinports/base
./configure
make all install
make clean
echo "file:///darwinports/dports" > /opt/local/etc/ports/sources.conf
echo "BatchMode yes" >> /etc/ssh_config
EOF
	chmod 755 $dir/bootstrap.sh
	echo "Bootstrapping darwinports in chroot"
	/sbin/mount_devfs devfs ${dir}/dev
	/sbin/mount_fdesc -o union fdesc ${dir}/dev
	chroot $dir /bootstrap.sh && rm $dir/bootstrap.sh
	umount -f ${dir}/dev
	umount -f ${dir}/dev
	hdiutil detach $BASEDEV -force >& /dev/null && BASEDEV=""
}

# Set up the base chroot image
prepchroot() {
	dir=$1
	rm -f ${CHROOTBASE}.shadow
	BASEDEV=`hdiutil attach ${CHROOTBASE} -mountpoint $dir -shadow -noverify 2>&1 | awk '/dev/ {if (x == 0) {print $1; x = 1}}'`
	mkdir -p $dir/.vol
 	DPORTSDEV=`hdiutil attach ${DPORTSCACHE} -mountpoint $dir/opt/local/var/db/dports -union -noverify 2>&1 | awk '/dev/ {if (x == 0) {print $1; x = 1}}'`
	/sbin/mount_devfs devfs $dir/dev || bomb "unable to mount devfs"
	/sbin/mount_fdesc -o union fdesc $dir/dev || bomb "unable to mount fdesc"
}

# Undo the work of prepchroot
teardownchroot() {
	dir=$1
	umount -f $dir/dev  || (echo "unable to umount devfs")
	umount -f $dir/dev  || (echo "unable to umount fdesc")
	[ -z "$DPORTSDEV" ] || (hdiutil detach $DPORTSDEV -force >& /dev/null || bomb "unable to detach DPORTSDEV")
	DPORTSDEV=""
	if [ ! -z "$BASEDEV" ]; then
		if ! hdiutil detach $BASEDEV -force >& /dev/null; then
			echo "Warning: Unable to detach BASEDEV ($BASEDEV)"
		fi
	fi
}

# main:  This is where we start the show.
TGTPORTS=""
PKGTYPE=mpkg

if [ $# -lt 1 ]; then
	echo "Usage: $0 chrootdir [-p pkgtype] [targetportsfile]"
	exit 1
else
	DIR=$1
	shift
	if [ $# -gt 1 ]; then
		if [ $1 = "-p" ]; then
		    shift
		    PKGTYPE=$1
		    shift
		fi
	fi
	if [ $# -gt 0 ]; then
		TGTPORTS=$1
	fi
fi

mkdir -p outputdir/summary outputdir/Packages outputdir/logs/succeeded outputdir/logs/failed outputdir/tmp

if [ -z "$TGTPORTS" ]; then
	if [ -f PortIndex ]; then
		PINDEX=PortIndex
	elif [ -f darwinports/dports/PortIndex ]; then
		PINDEX=darwinports/dports/PortIndex
	else
		echo "I need a PortIndex file to work from - please put one in the"
		echo "current directory or unpack a darwinports distribution to get it from"
		exit 1
	fi
	TGTPORTS=outputdir/summary/portsrun
	awk 'NF == 2 {print $1}' $PINDEX > $TGTPORTS
else
	echo "Using command-line provided target of $TGTPORTS"
fi

mkchrootbase $DIR
ARCH="`uname -p`"
if [ "${ARCH}" = "powerpc" ]; then
	ARCH=ppc
fi

echo "Starting packaging run for `wc -l $TGTPORTS | awk '{print $1}'` ports."
for pkg in `cat $TGTPORTS`; do
	if [ -f badports.txt ]; then
		if ! grep -q $pkg badports.txt; then
		    continue
		fi
	fi
	prepchroot $DIR
	echo "Starting packaging run for $pkg"
	echo "#!/bin/sh" > $DIR/bootstrap.sh
	echo 'export PATH=$PATH:/opt/local/bin' >> $DIR/bootstrap.sh
	echo '/sbin/mount_volfs /.vol' >> $DIR/bootstrap.sh
	echo "mkdir -p /Package" >> $DIR/bootstrap.sh
	echo "rm -f /tmp/success" >> $DIR/bootstrap.sh
	echo "if port -v $PKGTYPE $pkg package.destpath=/Package >& /tmp/$pkg.log; then touch /tmp/success; fi" >> $DIR/bootstrap.sh
	echo 'umount -f /.vol || (echo "unable to umount volfs"; exit 1)' >> $DIR/bootstrap.sh
	echo "exit 0" >> $DIR/bootstrap.sh
	chmod 755 $DIR/bootstrap.sh
	chroot $DIR /bootstrap.sh || bomb "bootstrap script in chroot returned failure status"
	if [ ! -f $DIR/tmp/success ]; then
		echo $pkg >> outputdir/summary/portsfailed
		type="failed"
	else
		echo $pkg >> outputdir/summary/portspackaged
		if [ "$PKGTYPE" = "mpkg" ]; then
		    mv $DIR/Package/*.mpkg outputdir/Packages/
		fi
		type="succeeded"
	fi
	mv $DIR/tmp/$pkg.log outputdir/logs/$type
	teardownchroot $DIR
	echo "Finished packaging run for $pkg ($type)"
done
echo "Packaging run complete."
exit 0
