New in Tcllib 1.4
=================
                                Tcllib 1.3      Tcllib 1.4
Module          Package         Old Version     New version     Comments
------          -------         -----------     -----------     -------------------------------
crc             crc16           --              1.0.1           More crc's
des                             --              0.8             Data Encryption Standard
------          -------         -----------     -----------     -------------------------------
doctools        doctools                --      1.0             Documentation tools, first time
                doctools::toc           --      0.1             as packages. Regular documenation,
                doctools::idx           --      0.1             table of contents, keyword indices,
                doctools::cvs           --      0.1             parsing of ChangeLogs and cvs logs.
                doctools::changelog     --      0.1
------          -------         -----------     -----------     -------------------------------
dns             resolv          --              1.0             Resolver on top of basic dns, mini-cache
log             logger          --              0.1             Alternate logging.
math            statistics      --              0.1             Statistics package
math            optimization    --              0.1             Optimization package
md4                             --              1.0             Another hash algorithm
ntp             time            --              1.0.1           TIME protocol
------          -------         -----------     -----------     -------------------------------
struct                          1.2.1           1.3       
                record          /                               Variable record's
                list            /                               Extended list manipulation
------          -------         -----------     -----------     -------------------------------
soundex                         --              1.0             Phonetic string comparison
------          -------         -----------     -----------     -------------------------------


Changes from Tcllib 1.3 to 1.4
==============================

Legend
        P :     Performance enhancement.
        B :     Bug fixes.
        D :     Documentation updates.
        EF:     Extended functionality.
        EX:     New examples.

                                Tcllib 1.3      Tcllib 1.4
Module          Package         Old Version     New version     Comments
------          -------         -----------     -----------     -------------------------------
base64          base64          2.2.1           2.2.2           P
                uuencode        1.0.1           1.0.2           B
                yencode         1.0             1.0.1           B
------          -------         -----------     -----------     -------------------------------
calendar                        0.1             0.2             B
cmdline                         1.2             1.2.1           B P
comm                            4.0             4.0.1           B P
control                         0.1.1           0.1.2           D
counter                         2.0             2.0.1           B P
------          -------         -----------     -----------     -------------------------------
crc             cksum           1.0             1.0.1           D,   Internal chunking
                crc32           1.0             1.0.1           B D, Internal chunking
                sum             1.0             1.0.1           D
------          -------         -----------     -----------     -------------------------------
csv                             0.3             0.4             B D
dns             dns             1.0.1           1.0.3           B,   TclUDP fallback
exif                            1.0             1.1             B P EF
fileutil                        1.4             1.5             B P
------          -------         -----------     -----------     -------------------------------
ftp             ftp             2.3.1           2.4             B EF
                ftp::geturl     0.1             0.2             B
------          -------         -----------     -----------     -------------------------------
ftpd                            1.1.2           1.1.3           B
html                            1.2.1           1.2.2           B
htmlparse                       0.3             0.3.1           B P
irc                             0.2             0.3             B EX
javascript                      1.0             1.0.1           D
log             log             1.0.1           1.0.2           D
math            math            1.2.1           1.2.2           D
md5                             1.4.2           1.4.3           B P
------          -------         -----------     -----------     -------------------------------
mime            mime            1.3.2           1.3.3           B D
                smtp            1.3.2           1.3.3           B D EX
------          -------         -----------     -----------     -------------------------------
ncgi                            1.2.1           1.2.2           B P
nntp                            0.2             0.2.1           D P
pop3                            1.5.1           1.6             B D EF
------          -------         -----------     -----------     -------------------------------
pop3d           pop3d           1.0             1.0.1           B D
                pop3d::dbox     1.0             1.1             EF
                pop3d::udb      1.0             1.0.1           D
------          -------         -----------     -----------     -------------------------------
profiler                        0.2             0.2.1           B P
report                          0.3             0.3.1           D
sha1                            1.0.2           1.0.3           B
smtpd                           1.0             1.2.1           B D EF
stooop                          4.4             4.4.1           D
------          -------         -----------     -----------     -------------------------------
struct                          1.2.1           1.3             B EF EX
                \ graph                                         Use cgraph if present.
------          -------         -----------     -----------     -------------------------------
textutil        textutil        0.5             0.6             P EF (TeX based hyphenation!)
                expander        1.0.1           1.2             EF
------          -------         -----------     -----------     -------------------------------
uri             uri             1.1.1           1.1.2           B P
                uri::urn        1.0             1.0.1           B
------          -------         -----------     -----------     -------------------------------
