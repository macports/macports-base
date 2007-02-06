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
    ftp://ftp.dti.ad.jp/pub/X/AfterStep/
    ftp://ftp.chg.ru/pub/X11/windowmanagers/afterstep/
}

set portfetch::mirror_sites::sites(apache) {
    http://www.apache.org/dist/
    ftp://ftp.planetmirror.com/pub/apache/dist/
    ftp://apache.mirrored.ca/
    ftp://ftp.is.co.za/Apache/dist/
    http://apache.planetmirror.com.au/dist/
    ftp://ftp.leo.org/pub/comp/general/infosys/www/daemons/apache/dist/
    ftp://ftp.infoscience.co.jp/pub/net/apache/dist/
}

set portfetch::mirror_sites::sites(freebsd) {
    ftp://ftp.FreeBSD.org/pub/FreeBSD/ports/distfiles/:nosubdir
    ftp://ftp.FreeBSD.org/pub/FreeBSD/ports/local-distfiles/:nosubdir
    ftp://ftp.se.FreeBSD.org/pub/FreeBSD/ports/distfiles/:nosubdir
    ftp://ftp.se.FreeBSD.org/pub/FreeBSD/ports/local-distfiles/:nosubdir
    ftp://ftp.uk.FreeBSD.org/pub/FreeBSD/ports/distfiles/:nosubdir
    ftp://ftp.uk.FreeBSD.org/pub/FreeBSD/ports/local-distfiles/:nosubdir
    ftp://ftp.ru.FreeBSD.org/pub/FreeBSD/ports/distfiles/:nosubdir
    ftp://ftp.ru.FreeBSD.org/pub/FreeBSD/ports/local-distfiles/:nosubdir
    ftp://ftp.jp.FreeBSD.org/pub/FreeBSD/ports/distfiles/:nosubdir
    ftp://ftp.jp.FreeBSD.org/pub/FreeBSD/ports/local-distfiles/:nosubdir
    ftp://ftp.tw.FreeBSD.org/pub/FreeBSD/ports/distfiles/:nosubdir
    ftp://ftp.tw.FreeBSD.org/pub/FreeBSD/ports/local-distfiles/:nosubdir
}

set portfetch::mirror_sites::sites(gnome) {
    http://ftp.rpmfind.net/linux/gnome.org/
    http://archive.progeny.com/GNOME/
    http://mirror.clarkson.edu/pub/gnome/
    http://mirror.aarnet.edu.au/pub/GNOME/
    http://www.download-ftp-center.com/mirrors/gnome.org/
    http://ftp.unina.it/pub/linux/GNOME
    http://fr.rpmfind.net/linux/gnome.org/
    http://fr2.rpmfind.net/linux/gnome.org/
    http://ftp.acc.umu.se/pub/GNOME/
    http://ftp.belnet.be/mirror/ftp.gnome.org/
    http://ftp.linux.org.uk/mirrors/ftp.gnome.org/
    http://www.mirror.ac.uk/sites/ftp.gnome.org/pub/GNOME/
    http://www.zentek-international.com/mirrors/gnome/
    http://ftp.nara.wide.ad.jp/pub/X11/GNOME/
    http://archive.progeny.com/GNOME/
    http://ftp.gnome.org/pub/GNOME/
    ftp://ftp.cse.buffalo.edu/pub/Gnome
    ftp://ftp.ussg.iu.edu/pub/gnome/
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
    ftp://ftp.gnu.org/gnu/
    ftp://ftp.uu.net/archive/systems/gnu/
    ftp://ftp.de.uu.net/pub/gnu/
    ftp://ftp.funet.fi/pub/gnu/prep/
    ftp://ftp.leo.org/pub/comp/os/unix/gnu/
    ftp://ftp.digex.net/pub/gnu/
    ftp://ftp.wustl.edu/mirrors/gnu/
    ftp://ftp.kddlabs.co.jp/pub/gnu/
    ftp://ftp.dti.ad.jp/pub/GNU/
    ftp://ftp.mirror.ac.uk/sites/ftp.gnu.org/gnu/
    ftp://sunsite.org.uk/Mirrors/ftp.gnu.org/pub/gnu/
    ftp://ftp.informatik.hu-berlin.de/pub/gnu/
    ftp://ftp.rediris.es/mirror/gnu/
    ftp://ftp.lip6.fr/pub/gnu/
    ftp://ftp.chg.ru/pub/gnu/
}

set portfetch::mirror_sites::sites(gnustep) {
    http://ftp.easynet.nl/mirror/GNUstep/pub/gnustep/
    ftp://ftp.easynet.nl/mirror/GNUstep/pub/gnustep/
    http://www.peanuts.org/peanuts/Mirrors/GNUstep/gnustep/
    http://ftpmain.gnustep.org/pub/gnustep/
    ftp://ftp.gnustep.org/pub/gnustep/
    http://archive.progeny.com/gnustep/
    ftp://archive.progeny.com/gnustep/
}

set portfetch::mirror_sites::sites(isc) {
    ftp://ftp.isc.org/isc/
    ftp://gd.tuwien.ac.at/infosys/servers/isc/
    ftp://ftp.ciril.fr/pub/isc/
    ftp://ftp.grolier.fr/pub/isc/
    ftp://ftp.funet.fi/pub/mirrors/ftp.isc.org/isc/
    ftp://ftp.freenet.de/pub/ftp.isc.org/isc/
    ftp://ftp.fsn.hu/pub/isc/
    ftp://ftp.kyushu-u.ac.jp/pub/Net/isc/
    ftp://ftp.iij.ad.jp/pub/network/isc/
    ftp://ftp.dti.ad.jp/pub/net/isc/
    ftp://ftp.u-aizu.ac.jp/pub/net/isc/
    ftp://ftp.linux.lv/pub/software/isc/
    ftp://ftp.task.gda.pl/mirror/ftp.isc.org/isc/
    ftp://ftp.cdu.elektra.ru/pub/unix/isc/
    ftp://ftp.si.uniovi.es/mirror/isc/
    ftp://ftp.sunet.se/pub/network/isc/
    ftp://ftp.chl.chalmers.se/pub/unix/network/isc/
    ftp://unix.hensa.ac.uk/mirrors/ftp.isc.org/isc/
    ftp://ftp.epix.net/pub/isc/
    ftp://ftp.nominum.com/pub/isc/
    ftp://ftp.nerdc.ufl.edu/pub/mirrors/ftp.isc.org/isc/
    ftp://ftp.ripe.net/mirrors/sites/ftp.isc.org/isc/
    ftp://ftp.nl.uu.net/pub/mirrors/ftp.isc.org/
    ftp://ftp.pop-mg.com.br/pub/isc/
    ftp://ftp.ntua.gr/pub/net/isc/isc/
    ftp://ftp.ulak.net.tr/pub/networking/isc/
    ftp://ftp.metu.edu.tr/pub/mirrors/ftp.isc.org/
}

set portfetch::mirror_sites::sites(kde) {
    http://kde.mirrors.hoobly.com/
    http://gd.tuwien.ac.at/kde/
    ftp://ftp.oregonstate.edu/pub/kde/
    ftp://ftp.solnet.ch/mirror/KDE/
    http://mirrors.isc.org/pub/kde/
    ftp://ftp.kde.org/pub/kde/
    http://ftp.gtlib.cc.gatech.edu/pub/kde/
    http://ftp.du.se/pub/mirrors/kde/
    http://kde.mirrors.tds.net/pub/kde
    http://ftp.caliu.info/pub/mirrors/kde
    http://ftp.tiscali.nl/kde/
}

set portfetch::mirror_sites::sites(macports) {
    http://svn.macosforge.org/repository/macports/distfiles/
    http://svn.macosforge.org/repository/macports/distfiles/general/:nosubdir
}

set portfetch::mirror_sites::sites(opendarwin) {
    http://distfiles-od.opendarwin.org/:mirror
    http://distfiles-msn.opendarwin.org/:mirror
    http://distfiles-bay13.opendarwin.org/:mirror
    http://distfiles-od.opendarwin.org/:nosubdir
    http://distfiles-msn.opendarwin.org/:nosubdir
    http://distfiles-bay13.opendarwin.org/:nosubdir
}

set portfetch::mirror_sites::sites(perl_cpan) {
    ftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module/
    ftp://ftp.cpan.org/pub/CPAN/modules/by-module/
    http://www.cpan.dk/CPAN/modules/by-module/
    ftp://uiarchive.uiuc.edu/pub/ftp/cpan.cse.msu.edu/modules/by-module/
    ftp://ftp.kddlabs.co.jp/lang/perl/CPAN/modules/by-module/
    ftp://ftp.dti.ad.jp/pub/lang/CPAN/modules/by-module/
    ftp://ftp.sunet.se/pub/lang/perl/CPAN/modules/by-module/
    ftp://mirror.hiwaay.net/CPAN/modules/by-module/
    ftp://ftp.bora.net/pub/CPAN/modules/by-module/
    ftp://ftp.mirror.ac.uk/sites/ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module/
    ftp://bioinfo.weizmann.ac.il/pub/software/perl/CPAN/modules/by-module/
    ftp://csociety-ftp.ecn.purdue.edu/pub/CPAN/modules/by-module/
    ftp://ftp.auckland.ac.nz/pub/perl/CPAN/modules/by-module/
    ftp://ftp.isu.net.sa/pub/CPAN/modules/by-module/
    ftp://ftp.ucr.ac.cr/pub/Unix/CPAN/modules/by-module/
    ftp://ftp.cs.colorado.edu/pub/perl/CPAN/modules/by-module/
    ftp://cpan.pop-mg.com.br/pub/CPAN/modules/by-module/
    ftp://ftp.is.co.za/programming/perl/CPAN/modules/by-module/
    http://cpan.shellhung.org/modules/by-module/
    ftp://sunsite.org.uk/packages/perl/CPAN/modules/by-module/
    ftp://ftp.chg.ru/pub/lang/perl/CPAN/modules/by-module/
}

set portfetch::mirror_sites::sites(ruby) {
    ftp://xyz.lcs.mit.edu/pub/ruby/
    http://www.ibiblio.org/pub/languages/ruby/
    ftp://ftp.iij.ad.jp/pub/lang/ruby/
    ftp://ftp.ruby-lang.org/pub/ruby/
    ftp://ftp.fu-berlin.de/unix/languages/ruby/
    ftp://ftp.easynet.be/ruby/ruby/
    ftp://ftp.ntua.gr/pub/lang/ruby/
    ftp://ftp.chg.ru/pub/lang/ruby/
    ftp://ftp.kr.FreeBSD.org/pub/ruby/
    http://mirrors.sunsite.dk/ruby/
    ftp://ftp.iDaemons.org/pub/mirror/ftp.ruby-lang.org/ruby/
}

set portfetch::mirror_sites::sites(sourceforge) {
    http://downloads.sourceforge.net/
    http://easynews.dl.sourceforge.net/
    http://ufpr.dl.sourceforge.net/
    http://kent.dl.sourceforge.net/
    http://jaist.dl.sourceforge.net
}

set portfetch::mirror_sites::sites(sunsite) {
    http://www.ibiblio.org/pub/Linux/
    http://linux.dsi.internet2.edu/
    ftp://ftp.unicamp.br/pub/systems/Linux/
    ftp://ftp.tuwien.ac.at/pub/linux/ibiblio/
    ftp://sunsite.cnlab-switch.ch/mirror/linux/sunsite/
    ftp://ftp.cs.tu-berlin.de/pub/linux/Mirrors/sunsite.unc.edu/
    ftp://ftp.fu-berlin.de/unix/linux/mirrors/sunsite.unc.edu/
    ftp://ftp.uni-jena.de/pub/linux/MIRROR.sunsite/
    ftp://ftp.rz.uni-karlsruhe.de/pub/mirror/ftp.uni-tuebingen.de/pub/linux/mirrors/ftp.metalab.unc.edu/pub/Linux/
    ftp://ftp.uni-magdeburg.de/pub/mirror/linux/ftp.metalab.unc.edu/
    ftp://ftp.uni-stuttgart.de/pub/mirror/sunsite.unc.edu/pub/Linux/
    ftp://ftp.informatik.rwth-aachen.de/pub/comp/Linux/sunsite.unc.edu/
    ftp://ftp.lip6.fr/pub/linux/sunsite/
    ftp://ftp.uvsq.fr/pub5/linux/sunsite/
    ftp://ftp.leidenuniv.nl/pub/linux/sunsite/
    ftp://ftp.nvg.ntnu.no/pub/mirrors/metalab.unc.edu/
    ftp://ftp.icm.edu.pl/vol/rzm1/linux-sunsite/
    ftp://ftp.pku.edu.cn/pub/linux/
    ftp://ftp.cse.cuhk.edu.hk/pub4/Linux/
    ftp://ftp.kobe-u.ac.jp/pub/Linux/metalab.unc.edu/
    ftp://ftp.kddlabs.co.jp/Linux/metalab.unc.edu/
    ftp://ftp.dacom.co.kr/pub/mirrors/metalab.unc.edu/Linux/
    ftp://ftp.funet.fi/pub/Linux/mirrors/metalab/
    ftp://sunsite.doc.ic.ac.uk/packages/linux/sunsite.unc-mirror/
    ftp://ftp.is.co.za/linux/sunsite/
    ftp://ftp.chg.ru/pub/Linux/sunsite/
}

set portfetch::mirror_sites::sites(tcltk) {
    ftp://ftp.scriptics.com/pub/tcl/
    ftp://sunsite.utk.edu/pub/tcl/
    ftp://ftp.funet.fi/pub/languages/tcl/tcl/
    ftp://ftp.kddlabs.co.jp/lang/tcl/ftp.scriptics.com/
    ftp://ftp.srcc.msu.su/mirror/ftp.scriptics.com/pub/tcl/
    ftp://ftp.mirror.ac.uk/sites/ftp.scriptics.com/pub/tcl/
    ftp://sunsite.org.uk/Mirrors/ftp.scriptics.com/pub/tcl/
}

set portfetch::mirror_sites::sites(xcontrib) {
    ftp://ftp.net.ohio-state.edu/pub/X11/contrib/
    ftp://ftp.gwdg.de/pub/x11/x.org/contrib/
    ftp://ftp.duke.edu/pub/X11/contrib/
    ftp://ftp.x.org/contrib/
    ftp://ftp.sunet.se/pub/X11/contrib/
    ftp://ftp.dti.ad.jp/pub/X/XFree86/X.Org/contrib/
    ftp://ftp.kddlabs.co.jp/X11/contrib/
    ftp://mirror.xmission.com/X/contrib/
    ftp://ftp2.x.org/contrib/
    ftp://sunsite.tus.ac.jp/pub/archives/X11/contrib/
    ftp://gd.tuwien.ac.at/hci/x.org/contrib/
    ftp://ftp.sunet.se/pub/X11/contrib/
    ftp://ftp.mirror.ac.uk/sites/ftp.x.org/contrib/
    ftp://ftp.dl.ac.uk/src/X/contrib/
    ftp://sunsite.org.uk/Mirrors/ftp.x.org/contrib/
    ftp://ftp.chg.ru/pub/X11/contrib/
}

set portfetch::mirror_sites::sites(xfree) {
    ftp://ftp.rge.com/pub/X/XFree86/
    ftp://archive.progeny.com/XFree86/
    ftp://ftp.mirrorcentral.com/pub/XFree86/
    ftp://ftp.dti.ad.jp/pub/X/XFree86/XFree86/
    ftp://gd.tuwien.Ac.at/hci/X11/XFree86/
    ftp://ftp.fit.vutbr.cz/pub/XFree86/
    ftp://ftp.free.fr/pub/XFree86/
    ftp://mir1.ovh.net/ftp.xfree86.org/
    ftp://ftp.lami.univ-evry.fr/XFree86/
    ftp://ftp.cs.tu-berlin.de/pub/X/XFree86/
    ftp://ftp.gwdg.de/pub/xfree86/XFree86/
    http://ftp-stud.fht-esslingen.de/pub/Mirrors/ftp.xfree86.org/XFree86/
    ftp://ftp.rediris.es/mirror/XFree86/
    ftp://ftp.esat.net/pub/X11/XFree86/
    ftp://ftp.nl.uu.net/pub/XFree86/
    ftp://sunsite.uio.no/pub/XFree86/
    ftp://ftp.task.gda.pl/pub/XFree86/
    ftp://ftp.physics.uvt.ro/pub/XFree86/
    ftp://ftp.chg.ru/pub/XFree86/
    ftp://ftp.xfree86.org/pub/XFree86/
}

set portfetch::mirror_sites::sites(openbsd) {
    ftp://ftp.openbsd.org/pub/OpenBSD/
    ftp://ftp.de.openbsd.org/unix/OpenBSD/
    ftp://ftp.jp.openbsd.org/pub/OpenBSD/
    ftp://ftp.ca.openbsd.org/unix/OpenBSD/
    http://ftp.uni-stuttgart.de/pub/OpenBSD/
    http://carroll.cac.psu.edu/pub/OpenBSD/
    http://mirror.pacific.net.au/OpenBSD/
    http://ftp.chg.ru/pub/OpenBSD/
    ftp://ftp.kd85.com/pub/OpenBSD/
    ftp://openbsd.informatik.uni-erlangen.de/pub/OpenBSD/
    ftp://gd.tuwien.ac.at/opsys/OpenBSD/
    ftp://reptile.kd85.com/pub/OpenBSD/
    ftp://muk.kd85.com/pub/OpenBSD/
    ftp://ftp.stacken.kth.se/pub/OpenBSD/
    ftp://ftp3.usa.openbsd.org/pub/OpenBSD/
    ftp://ftp5.usa.openbsd.org/pub/OpenBSD/
    ftp://rt.fm/pub/OpenBSD/
    ftp://ftp.openbsd.md5.com.ar/pub/OpenBSD/
}

set portfetch::mirror_sites::sites(postgresql) {
    ftp://ftp2.ch.postgresql.org/mirror/postgresql/
    ftp://ftp3.us.postgresql.org/pub/postgresql/
    ftp://ftp.postgresql.org/pub/
    ftp://ftp.de.postgresql.org/mirror/postgresql/
    ftp://ftp.fr.postgresql.org/
    ftp://ftp.jp.postgresql.org/
    ftp://ftp2.uk.postgresql.org/
}
