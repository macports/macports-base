Overview
========

	4 new packages		in 2 new modules.
	2 new packages		in 2 existing modules.
	9 changed packages	in 9 modules.

New in Tcllib 1.11.1
==================

Module          Package                 New Version     Comments
------          -------                 -----------     -----------------------
cache		cache::async		0.1		In-memory cache, async result return.
------          -------                 -----------     -----------------------
map		map::slippy		0.1		Open Street Map. Commons,
		map::slippy::fetcher	0.1		fetching map tiles, and
		map::slippy::cache	0.1		local cache of map tiles.
------          -------                 -----------     -----------------------
uevent		uevent::onidle		0.1		Merge idle requests for some action.
------          -------                 -----------     -----------------------
struct		struct::graph::op	0.9		Graph operations, GSoC 2008
------          -------                 -----------     -----------------------

Changes from Tcllib 1.11 to 1.11.1
==================================

                                Tcllib 1.11     Tcllib 1.11.1
Module          Package         Old version     New Version     Comments
------          -------         -----------     -----------     ---------------
base64		yencode		1.1.1		1.1.2		B
dns		dns		1.3.2		1.3.3		B
doctools	doctools	1.3.5		1.4		EF, D, T
fileutil	fileutil	1.13.4		1.13.5		B
ldap		ldap		1.7		1.8		EF
math		math::linalg	1.0.1		1.1		EF, B, T
nns		nameserv	0.4.1		0.4.2		B
struct		struct::graph	2.3		2.3.1		B
------          -------         -----------     -----------     ---------------

Invisible changes (no version change)
------          -------         -----------     -----------     ---------------
asn		asn				0.8		D
base64		uuencode			1.1.4		T
tar		tar				0.4		D
------          -------         -----------     -----------     ---------------

Legend  Change  Details Comments
	------	-------	---------
        Major   API:    ** incompatible ** API changes.

        Minor   EF :    Extended functionality, API.
                I  :    Major rewrite, but no API change

        Patch   B  :    Bug fixes.
                EX :    New examples.
                P  :    Performance enhancement.

        None    T  :    Testsuite changes.
                D  :    Documentation updates.
