New in Tcllib 1.6
=================
                                Tcllib 1.4      Tcllib 1.6
Module          Package         Old version     New Version     Comments
------          -------         -----------     -----------     -------------------------------
inifile                         --              0.1             Handling of Window .ini files.
------          -------         -----------     -----------     -------------------------------
md5crypt                        --              1.0.0           MD5 based password hashing.
multiplexer                     --              0.2             Message multiplexing.
snit                            --              0.92            pure-Tcl OO system.
------          -------         -----------     -----------     -------------------------------
struct                          1.3             2.0           
                \ set                                           Set manipulation.
------          -------         -----------     -----------     -------------------------------


Changes from Tcllib 1.4 to 1.6
==============================

Legend
        API:    ** incompatible ** API changes. > Implies change of major version.
        EF :    Extended functionality, API.    > Implies change of minor verson.
        B  :    Bug fixes.                     \
        D  :    Documentation updates.          > Implies change of patchlevel.
        EX :    New examples.                   >
        P  :    Performance enhancement.       /

                                Tcllib 1.4      Tcllib 1.6
Module          Package         Old version     New Version     Comments
------          -------         -----------     -----------     -------------------------------
base64          base64          2.2.2           2.3		B, EF (Trf)
                uuencode        1.0.2           1.1		EF (critcl)
                yencode         1.0.1           1.1		EF (critcl)
------          -------         -----------     -----------     -------------------------------
cmdline                         1.2.1           1.2.2		B
comm                            4.0.1           4.2		B, EF (async return callback)
counter                         2.0.1           2.0.2		B
------          -------         -----------     -----------     -------------------------------
crc             crc16		1.0.1		1.1		EF (xmodem)
                crc32           1.0.1           1.1		EF (-channel)
                sum             1.0.1           1.1.0		EF (-channel)
------          -------         -----------     -----------     -------------------------------
csv                             0.4             0.5		D
des				0.8		0.8.1		B
------          -------         -----------     -----------     -------------------------------
dns             dns             1.0.4           1.1		EF (SOA decode)
		resolv		1.0.2		1.0.3		P
------          -------         -----------     -----------     -------------------------------
doctools	doctools	1.0		1.0.1		B, +French msgcat
exif                            1.1             1.1.1		B
fileutil                        1.5             1.6		B, EF
------          -------         -----------     -----------     -------------------------------
ftp             ftp             2.4             2.4.1		B
------          -------         -----------     -----------     -------------------------------
ftpd                            1.1.3           1.2		B, EF
htmlparse                       0.3.1           1.0		B, +switch to struct 2.0
irc                             0.3             0.4		B, EF
------          -------         -----------     -----------	-------------------------------
log             log             1.0.2           1.1		B, EF
		logger		0.1		0.3		B, EF
------          -------         -----------     -----------	-------------------------------
math            math::calculus   0.5		0.5.1		B
		math::statistics 0.1		0.1.1		B
------          -------         -----------     -----------     -------------------------------
md4                             1.0.0		1.0.1		B
md5		                1.4.3           2.0.0		API ** INCOMPATIBLE API CHANGES **
------          -------         -----------     -----------     -------------------------------
mime            mime            1.3.3           1.3.4		B
                smtp            1.3.3           1.3.4		B, EF (tls)
------          -------         -----------     -----------     -------------------------------
ntp		time		1.0.1		1.0.2		B
------          -------         -----------     -----------     -------------------------------
ncgi                            1.2.2           1.2.3		B
pop3                            1.6             1.6.1		B
------          -------         -----------     -----------     -------------------------------
pop3d           pop3d           1.0.1           1.0.2		B
------          -------         -----------     -----------     -------------------------------
profiler                        0.2.1           0.2.2		B
------          -------         -----------     -----------     -------------------------------
struct1         struct          1.3             1.4             B, EF
struct          struct          1.3             2.0             API, B, EF
                \ list                                          | ** INCOMPATIBLE API CHANGES **
                \ graph                                         | ** INCOMPATIBLE API CHANGES **
                \ tree                                          | ** INCOMPATIBLE API CHANGES **
------          -------         -----------     -----------     -------------------------------
textutil        expander        1.2             1.2.1		B
uri             uri             1.1.2           1.1.3		B
------          -------         -----------     -----------     -------------------------------
