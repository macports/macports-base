#!/bin/sh

# Author: Jordan K. Hubbard
# Date: 2004/12/10
#
# Declare all the various shell functions which do the heavy lifting.
# If you want to see the main body of this script, go to the end of the file.

# What we want to call the base chroot images
CHROOTBASE=chrootbase.dmg
DISTFILES=distfiles.dmg

# Mount all the important bits a chroot build env needs.
mountchrootextras() {
	dir=$1
	/sbin/mount_devfs devfs ${dir}/dev
	/sbin/mount_fdesc -o union fdesc ${dir}/dev
}

# Undo the work of mountchrootextras
umountchrootextras() {
	dir=$1
	umount -f ${dir}/dev
	umount -f ${dir}/dev
}

# Everything we need to create the base chroot disk image (populated from host)
mkchrootimage() {
	if [ $# -lt 1 ]; then
		echo "Usage: mkchrootimage chrootdir"
		return 1
	fi

	dir=$1
	mkdir -p $dir
	DEV=""

	# Add to this list as you find minimum dependencies DP really needs.
	chrootfiles="bin sbin etc tmp var dev/null usr private Developer System/Library Library/Java"

	echo "Calculating chroot image size..."
	# start with this size to account for other overhead
	sz=2000000
	for i in $chrootfiles; do
		mysz=`cd /; du -sk $i |awk '{print $1}'`
		sz=$(($sz + $mysz))
	done
	echo "Creating bootstrap disk image of ${sz}K bytes"
	hdiutil create -size ${sz}k -fs HFSX ${CHROOTBASE} > /dev/null
	DEV=`hdiutil attach ${CHROOTBASE} -mountpoint $dir 2>&1 | awk '/dev/ {if (x == 0) {print $1; x = 1}}'`
	echo "Image attached as $DEV"
	echo "Copying chroot files into bootstrap disk image"
	for i in $chrootfiles; do
		pax -pe -rw /$i $dir 2>/dev/null
		# special case for pax
		cp /bin/pax $dir/bin/pax
	done
	if [ -f darwinports.tar.gz ]; then
		echo "Found darwinports.tar.gz - copying into chroot"
		tar -xpzf darwinports.tar.gz -C $dir
	elif [ -d darwinports ]; then
		pax -rw darwinports $dir
	else
		echo "no darwinports.tar.gz or darwinports directory found - please fix this and try again."
		return 1
	fi
	cat > $dir/bootstrap.sh << EOF
#!/bin/sh
cd darwinports/base
./configure
make all install
make clean
sed -e "s;portautoclean.*yes;portautoclean no;" < /etc/ports/ports.conf > /etc/ports/ports.conf.new && mv /etc/ports/ports.conf.new /etc/ports/ports.conf
EOF
	chmod 755 $dir/bootstrap.sh
	echo "Bootstrapping darwinports in chroot"
	mountchrootextras $dir
	chroot $dir /bootstrap.sh && rm $dir/bootstrap.sh
	umountchrootextras $dir
	[ -z "$DEV" ] || hdiutil detach $DEV >& /dev/null
	DEV=""
}

# Do whatever needs to be done to prep the chroot for actual package building
prepchroot() {
	dir=$1
	DEV=""; DISTDEV=""
	DEV=`hdiutil attach ${CHROOTBASE} -mountpoint $dir -readonly -shadow 2>&1 | awk '/dev/ {if (x == 0) {print $1; x = 1}}'`
	if [ -f $DISTFILES ]; then
		DISTDEV=`hdiutil attach ${DISTFILES} -mountpoint $dir/opt/local/var/db/dports/distfiles -union 2>&1 | awk '/dev/ {if (x == 0) {print $1; x = 1}}'`
	fi
}

# Undo the work of prepchroot
teardownchroot() {
	dir=$1
	[ -z "$DISTDEV" ] || hdiutil detach $DISTDEV >& /dev/null
	[ -z "$DEV" ] || hdiutil detach $DEV >& /dev/null
	rm -f ${CHROOTBASE}.shadow
	DEV=""; DISTDEV=""
}

# OK, here's where we kick it all off
TGTPORTS=""
if [ $# -lt 1 ]; then
	echo "Usage: $0 chrootdir [targetportsfile]"
	exit 1
else
	DIR=$1
	shift
	if [ $# -gt 0 ]; then
		TGTPORTS=$1
	fi
fi

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
	rm -rf outputdir
	mkdir -p outputdir/summary
	TGTPORTS=outputdir/summary/portsrun
	awk 'NF == 2 {print $1}' $PINDEX > $TGTPORTS
fi

if [ -f $CHROOTBASE ]; then
	echo "Using existing $CHROOTBASE file for efficiency"
else
	mkchrootimage $DIR
fi

mkdir -p outputdir/Packages outputdir/logs/succeeded outputdir/logs/failed

echo "Starting packaging run for `wc -l $TGTPORTS | awk '{print $1}'` ports."
for pkg in `cat $TGTPORTS`; do
	echo "Starting packaging run for $pkg"
	prepchroot $DIR
	echo "#!/bin/sh" > $DIR/bootstrap.sh
	echo 'export PATH=$PATH:/opt/local/bin' >> $DIR/bootstrap.sh
	echo "mkdir -p /.vol" >> $DIR/bootstrap.sh
	echo "/sbin/mount_volfs /.vol" >> $DIR/bootstrap.sh
	echo "/sbin/mount_devfs devfs /dev" >> $DIR/bootstrap.sh
        echo "/sbin/mount_fdesc -o union fdesc /dev" >> $DIR/bootstrap.sh
	echo "mkdir -p /Package" >> $DIR/bootstrap.sh
	echo "rm -f /tmp/success" >> $DIR/bootstrap.sh
	echo "if port -v mpkg $pkg package.destpath=/Package >& /tmp/$pkg.log; then touch /tmp/success; fi" >> $DIR/bootstrap.sh
	echo "umount /.vol" >> $DIR/bootstrap.sh
	echo "umount /dev" >> $DIR/bootstrap.sh
	echo "umount -f /dev" >> $DIR/bootstrap.sh
	echo "exit 0" >> $DIR/bootstrap.sh
	chmod 755 $DIR/bootstrap.sh
	chroot $DIR /bootstrap.sh
	if [ ! -f $DIR/tmp/success ]; then
		echo $pkg >> outputdir/summary/portsfailed
		type="failed"
	else
		echo $pkg >> outputdir/summary/portspackaged
		mv $DIR/Package/*.mpkg outputdir/Packages/
		type="succeeded"
	fi
	mv $DIR/tmp/$pkg.log outputdir/logs/$type
	teardownchroot $DIR
	echo "Finished packaging run for $pkg ($type)"
done
