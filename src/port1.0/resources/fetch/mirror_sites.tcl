# $Id$
# mirror_sites.tcl
#
# List of master site classes for use in Portfiles
# Most of these are taken shamelessly from FreeBSD.
#
# Appending :nosubdir as a tag to a mirror, means that
# the portfetch target will NOT append a subdirectory to
# the mirror site.
#
# Please keep this list sorted.

namespace eval portfetch::mirror_sites { }

set portfetch::mirror_sites::sites(afterstep) {
    ftp://ftp.afterstep.org/
    ftp://ftp.kddlabs.co.jp/X11/AfterStep/
    ftp://ftp.chg.ru/pub/X11/windowmanagers/afterstep/
}

set portfetch::mirror_sites::sites(apache) {
    http://www.apache.org/dist/
    http://archive.apache.org/dist/
    http://apache.planetmirror.com.au/dist/
    ftp://ftp.planetmirror.com/pub/apache/dist/
    ftp://ftp.is.co.za/Apache/dist/
    ftp://ftp.infoscience.co.jp/pub/net/apache/dist/
}

set portfetch::mirror_sites::sites(freebsd) {
    ftp://ftp.FreeBSD.org/pub/FreeBSD/ports/distfiles/:nosubdir
    ftp://ftp.FreeBSD.org/pub/FreeBSD/ports/local-distfiles/:nosubdir
    ftp://ftp.uk.FreeBSD.org/pub/FreeBSD/ports/distfiles/:nosubdir
    ftp://ftp.uk.FreeBSD.org/pub/FreeBSD/ports/local-distfiles/:nosubdir
    ftp://ftp.jp.FreeBSD.org/pub/FreeBSD/ports/distfiles/:nosubdir
    ftp://ftp.jp.FreeBSD.org/pub/FreeBSD/ports/local-distfiles/:nosubdir
    ftp://ftp.tw.FreeBSD.org/pub/FreeBSD/ports/distfiles/:nosubdir
    ftp://ftp.tw.FreeBSD.org/pub/FreeBSD/ports/local-distfiles/:nosubdir
}

set portfetch::mirror_sites::sites(gnome) {
    http://mandril.creatis.insa-lyon.fr/linux/gnome.org/
    http://mirror.aarnet.edu.au/pub/GNOME/
    http://ftp.unina.it/pub/linux/GNOME/
    http://fr.rpmfind.net/linux/gnome.org/
    http://fr2.rpmfind.net/linux/gnome.org/
    http://ftp.acc.umu.se/pub/GNOME/
    http://ftp.belnet.be/mirror/ftp.gnome.org/
    http://ftp.linux.org.uk/mirrors/ftp.gnome.org/
    http://ftp.nara.wide.ad.jp/pub/X11/GNOME/
    http://ftp.gnome.org/pub/GNOME/
    ftp://mirror.pacific.net.au/linux/GNOME
    ftp://ftp.dataplus.se/pub/GNOME/
    ftp://ftp.dit.upm.es/pub/GNOME/
    ftp://ftp.no.gnome.org/pub/GNOME/
    ftp://ftp.isu.edu.tw/pub/Unix/Desktop/GNOME/
    ftp://ftp.nara.wide.ad.jp/pub/X11/GNOME/
    ftp://ftp.chg.ru/pub/X11/gnome/
    ftp://ftp.kddlabs.co.jp/pub/GNOME/
    ftp://ftp.dti.ad.jp/pub/X/gnome/
}

set portfetch::mirror_sites::sites(gnu) {
    http://ftp.gnu.org/gnu/
    ftp://ftp.gnu.org/gnu/
    ftp://ftp.uu.net/archive/systems/gnu/
    ftp://ftp.funet.fi/pub/gnu/prep/
    ftp://ftp.kddlabs.co.jp/pub/gnu/
    ftp://ftp.dti.ad.jp/pub/GNU/
    ftp://ftp.informatik.hu-berlin.de/pub/gnu/
    ftp://ftp.lip6.fr/pub/gnu/
    ftp://ftp.chg.ru/pub/gnu/
    ftp://ftp.mirror.ac.uk/sites/ftp.gnu.org/gnu/
    ftp://ftp.gnu.org/old-gnu/
}

set portfetch::mirror_sites::sites(gnupg) {
    http://ftp.gnupg.org/gcrypt/
    http://mirrors.rootmode.com/ftp.gnupg.org/
    http://ftp.freenet.de/pub/ftp.gnupg.org/gcrypt/
    ftp://ftp.gnupg.org/gcrypt/
}

set portfetch::mirror_sites::sites(gnustep) {
    http://ftp.easynet.nl/mirror/GNUstep/pub/gnustep/
    http://ftpmain.gnustep.org/pub/gnustep/
    ftp://ftp.easynet.nl/mirror/GNUstep/pub/gnustep/
    ftp://ftp.gnustep.org/pub/gnustep/
}

set portfetch::mirror_sites::sites(googlecode) {
    http://${name}.googlecode.com/files/
}

set portfetch::mirror_sites::sites(isc) {
    ftp://ftp.isc.org/isc/
    ftp://gd.tuwien.ac.at/infosys/servers/isc/
    ftp://ftp.ciril.fr/pub/isc/
    ftp://ftp.grolier.fr/pub/isc/
    ftp://ftp.funet.fi/pub/mirrors/ftp.isc.org/isc/
    ftp://ftp.freenet.de/pub/ftp.isc.org/isc/
    ftp://ftp.fsn.hu/pub/isc/
    ftp://ftp.iij.ad.jp/pub/network/isc/
    ftp://ftp.dti.ad.jp/pub/net/isc/
    ftp://ftp.task.gda.pl/mirror/ftp.isc.org/isc/
    ftp://ftp.sunet.se/pub/network/isc/
    ftp://ftp.epix.net/pub/isc/
    ftp://ftp.nominum.com/pub/isc/
    ftp://ftp.ripe.net/mirrors/sites/ftp.isc.org/isc/
    ftp://ftp.pop-mg.com.br/pub/isc/
    ftp://ftp.ntua.gr/pub/net/isc/isc/
    ftp://ftp.metu.edu.tr/pub/mirrors/ftp.isc.org/
}

set portfetch::mirror_sites::sites(kde) {
    http://kde.mirrors.hoobly.com/
    http://gd.tuwien.ac.at/kde/
    http://mirrors.isc.org/pub/kde/
    http://ftp.gtlib.cc.gatech.edu/pub/kde/
    http://ftp.du.se/pub/mirrors/kde/
    http://kde.mirrors.tds.net/pub/kde
    http://ftp.caliu.info/pub/mirrors/kde
    ftp://ftp.oregonstate.edu/pub/kde/
    ftp://ftp.solnet.ch/mirror/KDE/
    ftp://ftp.kde.org/pub/kde/
}

set portfetch::mirror_sites::sites(macports) {
    http://svn.macports.org/repository/macports/distfiles/
    http://svn.macports.org/repository/macports/distfiles/general/:nosubdir
    http://svn.macports.org/repository/macports/downloads/
}

set portfetch::mirror_sites::sites(perl_cpan) {
    http://ftp.ucr.ac.cr/Unix/CPAN/modules/by-module/
    ftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module/
    ftp://ftp.cpan.org/pub/CPAN/modules/by-module/
    ftp://ftp.kddlabs.co.jp/lang/perl/CPAN/modules/by-module/
    ftp://ftp.sunet.se/pub/lang/perl/CPAN/modules/by-module/
    ftp://mirror.hiwaay.net/CPAN/modules/by-module/
    ftp://ftp.bora.net/pub/CPAN/modules/by-module/
    ftp://ftp.mirror.ac.uk/sites/ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module/
    ftp://csociety-ftp.ecn.purdue.edu/pub/CPAN/modules/by-module/
    ftp://ftp.auckland.ac.nz/pub/perl/CPAN/modules/by-module/
    ftp://ftp.cs.colorado.edu/pub/perl/CPAN/modules/by-module/
    ftp://cpan.pop-mg.com.br/pub/CPAN/modules/by-module/
    ftp://ftp.is.co.za/programming/perl/CPAN/modules/by-module/
    ftp://sunsite.org.uk/packages/perl/CPAN/modules/by-module/
    ftp://ftp.chg.ru/pub/lang/perl/CPAN/modules/by-module/
}

set portfetch::mirror_sites::sites(ruby) {
    http://www.ibiblio.org/pub/languages/ruby/
    http://mirrors.sunsite.dk/ruby/
    ftp://xyz.lcs.mit.edu/pub/ruby/
    ftp://ftp.iij.ad.jp/pub/lang/ruby/
    ftp://ftp.ruby-lang.org/pub/ruby/
    ftp://ftp.fu-berlin.de/unix/languages/ruby/
    ftp://ftp.easynet.be/ruby/ruby/
    ftp://ftp.ntua.gr/pub/lang/ruby/
    ftp://ftp.chg.ru/pub/lang/ruby/
    ftp://ftp.kr.FreeBSD.org/pub/ruby/
    ftp://ftp.iDaemons.org/pub/mirror/ftp.ruby-lang.org/ruby/
}

set portfetch::mirror_sites::sites(sourceforge) {
    http://downloads.sourceforge.net/
    http://easynews.dl.sourceforge.net/
    http://ufpr.dl.sourceforge.net/
    http://kent.dl.sourceforge.net/
    http://jaist.dl.sourceforge.net/
}

set portfetch::mirror_sites::sites(sourceforge_jp) {
    http://iij.dl.sourceforge.jp/
    http://osdn.dl.sourceforge.jp/
    http://jaist.dl.sourceforge.jp/
    http://keihanna.dl.sourceforge.jp/
    http://globalbase.dl.sourceforge.jp/
}

set portfetch::mirror_sites::sites(sunsite) {
    http://www.ibiblio.org/pub/Linux/
    ftp://ftp.unicamp.br/pub/systems/Linux/
    ftp://ftp.tuwien.ac.at/pub/linux/ibiblio/
    ftp://ftp.cs.tu-berlin.de/pub/linux/Mirrors/sunsite.unc.edu/
    ftp://ftp.lip6.fr/pub/linux/sunsite/
    ftp://ftp.nvg.ntnu.no/pub/mirrors/metalab.unc.edu/
    ftp://ftp.icm.edu.pl/vol/rzm1/linux-sunsite/
    ftp://ftp.cse.cuhk.edu.hk/pub4/Linux/
    ftp://ftp.kddlabs.co.jp/Linux/metalab.unc.edu/
    ftp://ftp.chg.ru/pub/Linux/sunsite/
}

set portfetch::mirror_sites::sites(tcltk) {
    ftp://ftp.funet.fi/pub/languages/tcl/tcl/
    ftp://ftp.kddlabs.co.jp/lang/tcl/ftp.scriptics.com/
}

set portfetch::mirror_sites::sites(xcontrib) {
    ftp://ftp.net.ohio-state.edu/pub/X11/contrib/
    ftp://ftp.gwdg.de/pub/x11/x.org/contrib/
    ftp://ftp.x.org/contrib/
    ftp://ftp2.x.org/contrib/
    ftp://ftp.mirror.ac.uk/sites/ftp.x.org/contrib/
}

set portfetch::mirror_sites::sites(xfree) {
    http://ftp-stud.fht-esslingen.de/pub/Mirrors/ftp.xfree86.org/XFree86/
    ftp://ftp.fit.vutbr.cz/pub/XFree86/
    ftp://mir1.ovh.net/ftp.xfree86.org/
    ftp://ftp.gwdg.de/pub/xfree86/XFree86/
    ftp://ftp.rediris.es/mirror/XFree86/
    ftp://ftp.esat.net/pub/X11/XFree86/
    ftp://sunsite.uio.no/pub/XFree86/
    ftp://ftp.task.gda.pl/pub/XFree86/
    ftp://ftp.physics.uvt.ro/pub/XFree86/
    ftp://ftp.chg.ru/pub/XFree86/
    ftp://ftp.xfree86.org/pub/XFree86/
}

set portfetch::mirror_sites::sites(openbsd) {
    http://mirror.roothell.org/pub/OpenBSD/
    http://ftp-stud.fht-esslingen.de/pub/OpenBSD/
    http://mirror.paranoidbsd.org/pub/OpenBSD/
    ftp://ftp.openbsd.org/pub/OpenBSD/
    ftp://ftp.jp.openbsd.org/pub/OpenBSD/
    ftp://carroll.cac.psu.edu/pub/OpenBSD/
    ftp://openbsd.informatik.uni-erlangen.de/pub/OpenBSD/
    ftp://gd.tuwien.ac.at/opsys/OpenBSD/
    ftp://ftp.stacken.kth.se/pub/OpenBSD/
    ftp://ftp3.usa.openbsd.org/pub/OpenBSD/
    ftp://ftp5.usa.openbsd.org/pub/OpenBSD/
    ftp://rt.fm/pub/OpenBSD/
    ftp://ftp.openbsd.md5.com.ar/pub/OpenBSD/
}

set portfetch::mirror_sites::sites(postgresql) {
    http://ftp8.us.postgresql.org/postgresql/
    http://ftp9.us.postgresql.org/pub/mirrors/postgresql/
    http://ftp7.de.postgresql.org/pub/ftp.postgresql.org/
    http://ftp2.jp.postgresql.org/pub/postgresql/
    ftp://ftp2.ch.postgresql.org/mirror/postgresql/
    ftp://ftp.postgresql.org/pub/
    ftp://ftp.de.postgresql.org/mirror/postgresql/
    ftp://ftp.fr.postgresql.org/
    ftp://ftp2.uk.postgresql.org/
}
