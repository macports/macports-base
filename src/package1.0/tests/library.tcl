proc env_init {} {
    global os.platform os.subplatform os.major os.arch epoch destpath package.destpath build_arch \
        configure.build_arch subport version revision package.flat maintainers description \
        categories homepage supported_archs porturl workpath distname license filespath portpath \
        pwd name platforms

    set os.platform darwin
    set os.subplatform macosx
    set os.major 9
    set os.version 9.0.0
    set os.arch i386
    set epoch 0

    set workpath $pwd/work
    set destpath $pwd/pkg
    set portpath $pwd
    set portdbpath $pwd/dbpath
    set filespath $pwd/files
    set build_arch i386
    set configure.build_arch $build_arch
    set package.destpath $pwd/pkg

    set name fondu
    set subport fondu
    set version 060102
    set distname fondu_src-060102
    set revision 1
    set platforms darwin
    set license BSD
    set package.flat no
    set maintainers {test@macports.org}
    set description test.description
    set categories test
    set supported_archs noarch
    set homepage "http://fondu.sourceforge.net/"
    set porturl "file://${pwd}"

    # mock mport_lookup, it normally needs a PortIndex
    proc mport_lookup {portname} {
        global porturl
        return [list $portname [list variants universal portdir print/${portname} description {A set of programs to interconvert between Mac font formats and pfb, ttf, otf and bdf files on UNIX.} homepage http://fondu.sourceforge.net/ epoch 0 platforms darwin name $portname license BSD maintainers nomaintainer version 060102 categories print revision 1 porturl $porturl]]
    }
}

