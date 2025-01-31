New in Tcllib 1.7
=================
                        		Tcllib 1.7
Module          Package 		New Version     Comments
------          ------- 		-----------     -------------------------------
asn                                     0.1		Partial ASN de- & encoder.
bee                                     0.1		B de- & encoder (BitTorrent Serialization)
------          -------                 -----------     -------------------------------
dns		ip                      1.0.0		IP address manipulation
		spf                     1.1.0		Sender Policy Framework
------          -------                 -----------     -------------------------------
grammar_fa	grammar::fa             0.1		Finite Automaton Container
		grammar::fa::dacceptor  0.1		FA acceptor
		grammar::fa::dexec      0.1		FA interpreter
		grammar::fa::op         0.1		FA operations
------          -------                 -----------     -------------------------------
http		autoproxy               1.2.0		Http proxy
------          -------                 -----------     -------------------------------
ident                                   0.42		RFC 1413 IDENT client
jpeg                                    0.1		JPEG images, meta data manipulation
ldap                                    1.2		RFC 2251 LDAP client
------          -------                 -----------     -------------------------------
math		math::complexnumbers    1.0		Complex number arithmetics
		math::constants         1.0		Important mathematical constants
		math::interpolate       1.0		Interpolation for n-dimensional data
		math::polynomials       1.0		Polynomial arithmetics
		math::rationalfunctions 1.0		Arithmetics on rationals over polynomials
		math::special           0.1		Bessel functions, Elliptics, ...
		math::fourier		1.0		Fourier Transform
------          -------                 -----------     -------------------------------
png                                     0.1		PNG images, meta data manipulation
rc4                                     1.0.0		RC4 stream cipher
------          -------                 -----------     -------------------------------
ripemd		ripemd128               1.0.0		RIPEMD Hash algorithm
		ripemd160               1.0.0		
------          -------                 -----------     -------------------------------
tar                                     0.1		Tar file creation & manipulation
------          -------                 -----------     -------------------------------
tie             tie                     1.0		Persistence for Tcl arrays.
		tie::std::array         1.0		Various data sources for the
		tie::std::dsource       1.0		persistence.
		tie::std::file          1.0		
		tie::std::log           1.0		
		tie::std::rarray        1.0		
------          -------                 -----------     -------------------------------
treeql					1.1		Tree Query Language, CoST inspired
------          -------                 -----------     -------------------------------
uuid                                    1.0.0		Generation of universally unique identifiers
------          ------- 		-----------     -------------------------------


Changes from Tcllib 1.6 to 1.7
==============================

Legend
        API:    ** incompatible ** API changes. > Implies change of major version.
        EF :    Extended functionality, API.    > Implies change of minor verson.
        B  :    Bug fixes.                     \
        D  :    Documentation updates.          > Implies change of patchlevel.
        EX :    New examples.                   >
        P  :    Performance enhancement.       /
	TS :	Test suite fix		       /

                                Tcllib 1.6.1    Tcllib 1.7
Module          Package         Old version     New Version     Comments
------          -------         -----------     -----------     -------------------------------
base64		base64		2.3		2.3.1     	D
		uuencode	1.1.1		1.1.2	   	B
		yencode		1.1		1.1.1     	D
------          -------         -----------     -----------     -------------------------------
crc		crc32		1.1.1		1.2	   	BF
------          -------         -----------     -----------     -------------------------------
cmdline				1.2.2		1.2.3   	D, TS
comm				4.2		4.2.1     	D
counter				2.0.2		2.0.3		B, P
des				0.8.1		0.8.2   	P
------          -------         -----------     -----------     -------------------------------
dns		dns		1.1		1.2.0   	B, EF (ipv6)
------          -------         -----------     -----------     -------------------------------
doctools	doctools	1.0.2		1.1      	D, B, P, EF
		- changelog     0.1		0.1.1   	D
		- cvs           0.1		0.1.1   	D
		- idx           0.1		0.2     	D, B, EF
		- toc           0.1		0.2     	D, B, EF
------          -------         -----------     -----------     -------------------------------
exif				1.1.1		1.1.2		B
fileutil			1.6.1		1.7	   	EF, D, TS
ftpd				1.2.1		1.2.2		B
html				1.2.2		1.2.3		D
htmlparse			1.0		1.1     	B, EF (empty tags)
irc				0.4		0.5     	P, EF (logger)
------          -------         -----------     -----------     -------------------------------
log		log		1.1.1		1.2		D, EF
		logger		0.3		0.5     	B, EF
------          -------         -----------     -----------     -------------------------------
math		- calculus      0.5.1		0.6     	EF (regula falsi)
		- optimize      0.1		0.2     	EF
		- statistics    0.1.1		0.1.2   	P
		- geometry	1.0.1		1.0.2		D
------          -------         -----------     -----------     -------------------------------
mime		mime		1.3.6		1.4     	Sync
		smtp		1.3.6		1.4     	D, EF (auth, sasl)
------          -------         -----------     -----------     -------------------------------
ntp		time		1.0.3		1.1     	B
------          -------         -----------     -----------     -------------------------------
pop3				1.6.1		1.6.2   	TS
------          -------         -----------     -----------     -------------------------------
pop3d		pop3d		1.0.2		1.0.3   	B (md5 switch)
		- dbox		1.0.1		1.0.2   	TS
------          -------         -----------     -----------     -------------------------------
smtpd				1.2.1		1.3.0   	B, EF (secure)
------          -------         -----------     -----------     -------------------------------
snit				0.93		0.97    	API, EF (macros, pragmas, hierarchical)
------          -------         -----------     -----------     -------------------------------
struct				2.0		2.1		Exploded into many packages
		- graph                         2.0		B
		- list                          1.4		 --
		- matrix                        2.0		B
		- pool                          1.2.1		 --
		- prioqueue                     1.3		 --
		- queue                         1.3		B
		- record                        1.2.1		B
		- set                           2.1		B
		- skiplist                      1.3		P
		- stack                         1.3		B
		- tree                          2.0		B, EF
------          -------         -----------     -----------     -------------------------------
textutil	textutil	0.6.1		0.6.2   	B
		- expander	1.2.1		1.3     	TS, D, B, EF (location)
------          -------         -----------     -----------     -------------------------------
uri		uri::urn	1.0.1		1.0.2   	B
------          -------         -----------     -----------     -------------------------------

Unchanged Modules/Packages
==========================

calendar, crc (cksum, crc16, sum), control, csv, dns (resolv),
ftp (ftp, ftp::geturl), inifile, javascript, math (math::fuzzy), md4,
md5, md5crypt, multiplexer, ncgi, nntp, profiler, report, sha1,
soundex, stoop (stooop, switched), pop3d (pop3d::udb), uri

