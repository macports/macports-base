#! /bin/sh
# repo2solv
#
# give it a directory of a local mirror of a repo and this
# tries to detect the repo type and generate one SOLV file on stdout

get_DESCRDIR () {
  local d=$(grep '^DESCRDIR' content | sed 's/^DESCRDIR[[:space:]]\+\(.*[^[:space:]]\)[[:space:]]*$/\1/')
  if  test -z "$d"; then
    echo suse/setup/descr
  else
    echo ${d}
  fi
}

test_susetags() {
  if test -s content; then
    DESCR=$(get_DESCRDIR)
    test -d $DESCR
    return $?
  else
    return 1
  fi
}

repomd_findfile() {
  local t=$1
  local p=$2
  local f
  if test -n "$t" -a -s repomd.xml ; then
    f=`repomdxml2solv -q $t:location < repomd.xml 2>/dev/null`
    f=${f##*/}
    if test -f "$f" ; then
      echo "$f"
      return
    fi
  fi
  if test -f "$p.bz2" ; then
    echo "$p.bz2"
  elif test -f "$p.gz" ; then
    echo "$p.gz"
  elif test -f "$p" ; then
    echo "$p"
  fi
}

repomd_decompress() {
  case $1 in
   *.gz) gzip -dc "$1" ;;
   *.bz2) bzip2 -dc "$1" ;;
   *.lzma) lzma -dc "$1" ;;
   *.xz) xz -dc "$1" ;;
   *) cat "$1" ;;
  esac
}

susetags_findfile() {
  if test -s "$1.xz" ; then
    echo "$1.xz"
  elif test -s "$1.lzma" ; then
    echo "$1.lzma"
  elif test -s "$1.bz2" ; then
    echo "$1.bz2"
  elif test -s "$1.gz" ; then
    echo "$1.gz"
  fi
}

susetags_findfile_cat() {
  if test -s "$1.xz" ; then
    xz -dc "$1.xz"
  elif test -s "$1.lzma" ; then
    lzma -dc "$1.lzma"
  elif test -s "$1.bz2" ; then
    bzip2 -dc "$1.bz2"
  elif test -s "$1.gz" ; then
    gzip -dc "$1.gz"
  elif test -s "$1" ; then
    cat "$1"
  fi
}

# signal an error if there is a problem
set -e

LANG=C
unset CDPATH
parser_options=${PARSER_OPTIONS:-}

findopt="-prune"
repotype=
addautooption=

while true ; do
  if test "$1" = "-o" ; then
    exec > "$2"
    shift
    shift
  elif test "$1" = "-R" ; then
    # recursive
    findopt=
    repotype=plaindir
    shift
  elif test "$1" = "-X" ; then
    addautooption=-X
    shift
  elif test "$1" = "-A" ; then
    shift
  else
    break
  fi
done

dir="$1"
cd "$dir" || exit 1

if test -z "$repotype" ; then
  # autodetect repository type
  if test -d repodata -o -f repomd.xml; then
    repotype=rpmmd
  elif test_susetags ; then
    repotype=susetags
  else
    repotype=plaindir
  fi
fi

if test "$repotype" = rpmmd ; then
  test -d repodata && {
    cd repodata || exit 2
  }

  primfile=
  primxml=`repomd_findfile primary primary.xml`
  if test -n "$primxml" -a -s "$primxml" ; then
    primfile=`mktemp` || exit 3
    (
     # fake tag to combine primary.xml and extensions
     # like susedata.xml, other.xml, filelists.xml
     echo '<rpmmd>'
     if test -f $primxml ; then
	repomd_decompress $primxml
         # add a newline
        echo
     fi
     susedataxml=`repomd_findfile susedata susedata.xml`
     if test -f "$susedataxml" ; then
	repomd_decompress "$susedataxml"
     fi
     echo '</rpmmd>'
    ) | sed 's/<?xml[^>]*>//g' | sed '1i\<?xml version="1.0" encoding="UTF-8"?>' | rpmmd2solv $parser_options > $primfile || exit 4
  fi

  prodfile=
  prodxml=`repomd_findfile products products.xml`
  if test -z "$prodxml" ; then
    prodxml=`repomd_findfile product product.xml`
  fi
  if test -n "$prodxml" -a -s "$prodxml" ; then
      prodfile=`mktemp` || exit 3
      repomd_decompress "$prodxml" | rpmmd2solv $parser_options > $prodfile || exit 4
  fi

  patternfile=
  patternxml=`repomd_findfile 'patterns' patterns.xml`
  if test -n "$patternxml" -a -s "$patternxml" ; then
      patternfile=`mktemp` || exit 3
      repomd_decompress "$patternxml" | rpmmd2solv $parser_options > $patternfile || exit 4
  fi

  # This contains repomd.xml
  # for now we only read some keys like timestamp
  repomdfile=
  repomdxml=`repomd_findfile '' repomd.xml`
  if test -n "$repomdxml" -a -s "$repomdxml" ; then
      repomdfile=`mktemp` || exit 3
      repomd_decompress "$repomdxml" | repomdxml2solv $parser_options > $repomdfile || exit 4
  fi

  # This contains suseinfo.xml, which is an extension to repomd.xml
  # for now we only read some keys like expiration and products
  suseinfofile=
  suseinfoxml=`repomd_findfile suseinfo suseinfo.xml`
  if test -n "$suseinfoxml" -a -s "$suseinfoxml" ; then
      suseinfofile=`mktemp` || exit 3
      repomd_decompress "$suseinfoxml" | repomdxml2solv $parser_options > $suseinfofile || exit 4
  fi

  # This contains a updateinfo.xml* and maybe patches
  updateinfofile=
  updateinfoxml=`repomd_findfile updateinfo updateinfo.xml`
  if test -n "$updateinfoxml" -a -s "$updateinfoxml" ; then
      updateinfofile=`mktemp` || exit 3
      repomd_decompress "$updateinfoxml" | updateinfoxml2solv $parser_options > $updateinfofile || exit 4
  fi

  # This contains a deltainfo.xml*
  deltainfofile=
  deltainfoxml=`repomd_findfile deltainfo deltainfo.xml`
  if test -z "$deltainfoxml"; then 
      deltainfoxml=`repomd_findfile prestodelta prestodelta.xml`
  fi
  if test -n "$deltainfoxml" -a -s "$deltainfoxml" ; then
      deltainfofile=`mktemp` || exit 3
      repomd_decompress "$deltainfoxml" | deltainfoxml2solv $parser_options > $deltainfofile || exit 4
  fi

  # This contains appdata
  appdataxml=
  appdatafile=
  if test -x /usr/bin/appdata2solv ; then
      appdataxml=`repomd_findfile appdata appdata.xml`
  fi
  if test -n "$appdataxml" -a -s "$appdataxml" ; then
      appdatafile=`mktemp` || exit 3
      repomd_decompress "$appdataxml" | appdata2solv $parser_options > $appdatafile || exit 4
  fi

  # Now merge primary, patches, updateinfo, and deltainfo
  mergesolv $addautooption $repomdfile $suseinfofile $primfile $prodfile $patternfile $updateinfofile $deltainfofile $appdatafile
  rm -f $repomdfile $suseinfofile $primfile $patternfile $prodfile $updateinfofile $deltainfofile $appdatafile

elif test "$repotype" = susetags ; then
  olddir=`pwd`
  DESCR=$(get_DESCRDIR)
  cd ${DESCR} || exit 2
  appdataxml=
  appdatafile=
  if test -x /usr/bin/appdata2solv ; then
      appdataxml=`susetags_findfile appdata.xml`
  fi
  if test -n "$appdataxml" ; then
      appdatafile=`mktemp` || exit 3
      repomd_decompress "$appdataxml" | appdata2solv $parser_options > $appdatafile || exit 4
      parser_options="-M $appdatafile $parser_options"
  fi
  (
    # First packages
    susetags_findfile_cat packages

    # DU
    susetags_findfile_cat packages.DU

    # Now default language
    susetags_findfile_cat packages.en

    # Now patterns.  Not simply those files matching *.pat{,.gz,bz2},
    # but only those mentioned in the file 'patterns'
    if test -f patterns ; then
      for i in `cat patterns`; do
        if test -s "$i" ; then
	  repomd_decompress "$i"
	fi
      done
    fi

    # Now all other packages.{lang}.  Needs to come last as it switches
    # languages for all following susetags files
    for i in packages.* ; do
      case $i in
	*.gz|*.bz2|*.xz|*.lzma) name="${i%.*}" ;;
	*) name="$i" ;;
      esac
      case $name in
	# ignore files we handled already
	*.DU | *.en | *.FL | packages ) continue ;;
	*)
	  suff=${name#packages.}
	  echo "=Lan: $suff"
	  repomd_decompress "$i"
      esac
    done

  ) | susetags2solv $addautooption -c "${olddir}/content" $parser_options || exit 4
  test -n "$appdatafile" && rm -f "$appdatafile"
  cd "$olddir"
elif test "$repotype" = plaindir ; then
  find * -name .\* -prune -o $findopt -name \*.delta.rpm -o -name \*.patch.rpm -o -name \*.rpm -a -type f -print0 | rpms2solv $addautooption -0 -m -
else
  echo "unknown repository type '$repotype'" >&2
  exit 1
fi
