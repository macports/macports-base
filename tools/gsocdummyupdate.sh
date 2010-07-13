#!/bin/bash

TARFILE=gsoc-dummy.tar.gz 
PORTFILE=$(port dir gsoc-dummy)/Portfile
USER=$(id -p | grep login | cut -f 2)
#edit following line to point GSOCDUMMYDIR to the directory containing
#"gsoc-dummy" tree
GSOCDUMMYDIR=/Users/"$USER"/.macports/GSoC

cd "$GSOCDUMMYDIR" && \
tar zcf "$TARFILE" gsoc-dummy && \
chown "$USER" "$TARFILE"

TMPFILE=/tmp/TempPortfile$(date +"%Y%m%d%H%M")
#just don't be nice, we need an empty file
if [ -f "$TMPFILE" ]; then rm "$TMPFILE"; fi;
touch /tmp/tempPortfile

read _ md5Hash <<< $(openssl md5 "$TARFILE") 
read _ shaHash <<< $(openssl sha1 "$TARFILE")
read _ rmdHash <<< $(openssl rmd160 "$TARFILE")

md5="checksums           md5     $md5Hash \\"
sha="                    sha1    $shaHash \\"
rmd="                    rmd160  $rmdHash"

read num _ <<< $(wc -l "$PORTFILE")
head -n $((num-3)) "$PORTFILE" > "$TMPFILE"
printf "\n%s\n%s\n%s" "$md5" "$sha" "$rmd" >> "$TMPFILE"
printf "Portfile updated with:\n%s\n%s\n%s\n\n" "$md5" "$sha" "$rmd"

#update Portfile
cp "$TMPFILE" "$PORTFILE"
#update distfile
mkdir -p /opt/mp-gsoc/var/macports/distfiles/gsoc-dummy/
cp "$TARFILE" /opt/mp-gsoc/var/macports/distfiles/gsoc-dummy
#clean status
port clean gsoc-dummy
#clean /tmp too
rm "$TMPFILE"

