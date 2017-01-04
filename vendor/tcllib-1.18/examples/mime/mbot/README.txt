

The README file                                                  M. Rose
                                            Dover Beach Consulting, Inc.
                                                           February 2002


                        The personal.tcl Mailbot


Abstract

   The personal.tcl mailbot implements a highly-specialized filter for
   personal messages.  It MUST not be used by people who receive mailing
   list traffic in their personal mailboxes.

Table of Contents

   1.    SYNOPSIS . . . . . . . . . . . . . . . . . . . . . . . . . .  2
   1.1   Requirements . . . . . . . . . . . . . . . . . . . . . . . .  2
   1.2   Copyrights . . . . . . . . . . . . . . . . . . . . . . . . .  2
   2.    PHILOSOPHY . . . . . . . . . . . . . . . . . . . . . . . . .  3
   2.1   Guest Lists  . . . . . . . . . . . . . . . . . . . . . . . .  4
   3.    BEHAVIOR . . . . . . . . . . . . . . . . . . . . . . . . . .  5
   3.1   Arguments  . . . . . . . . . . . . . . . . . . . . . . . . .  5
   3.2   Actions  . . . . . . . . . . . . . . . . . . . . . . . . . .  6
   3.3   The Configuration File . . . . . . . . . . . . . . . . . . .  7
   3.3.1 Configuration Options  . . . . . . . . . . . . . . . . . . .  7
   3.3.2 Configurable Procedures  . . . . . . . . . . . . . . . . . . 10
         References . . . . . . . . . . . . . . . . . . . . . . . . . 12
         Author's Address . . . . . . . . . . . . . . . . . . . . . . 12
   A.    Impersonal Mail  . . . . . . . . . . . . . . . . . . . . . . 13
   A.1   Configuration Options  . . . . . . . . . . . . . . . . . . . 14
   A.1.1 foldersDirectory . . . . . . . . . . . . . . . . . . . . . . 14
   A.1.2 foldersFile  . . . . . . . . . . . . . . . . . . . . . . . . 14
   A.1.3 announceMailboxes  . . . . . . . . . . . . . . . . . . . . . 14
   A.1.4 mappingFile  . . . . . . . . . . . . . . . . . . . . . . . . 14
   A.2   Configurable Procedures  . . . . . . . . . . . . . . . . . . 15
   A.2.1 impersonalMail . . . . . . . . . . . . . . . . . . . . . . . 15
   A.2.2 processFolder  . . . . . . . . . . . . . . . . . . . . . . . 16
   B.    An Example configFile  . . . . . . . . . . . . . . . . . . . 17
   C.    Acknowledgements . . . . . . . . . . . . . . . . . . . . . . 18












Rose                                                            [Page 1]

README                  The personal.tcl Mailbot           February 2002


1. SYNOPSIS

   Create a configuration file (Section 3.3) and add this line to your
   ".forward" file:

       "| LIB/mbot-1.1/personal.tcl -config FILE -user USER"

   where "LIB" is where the Tcl library lives, "FILE" is the name of
   your configuration file, and "USER" is your username.

1.1 Requirements

   This package requires:

   o  Tcl version 8.3 [1] or later

   o  tcl lib [2]

   o  TclX version 8.0 [3] or later


1.2 Copyrights

   (c) 1999-2002 Marshall T.  Rose

   Hold harmless the author, and any lawful use is allowed.

























Rose                                                            [Page 2]

README                  The personal.tcl Mailbot           February 2002


2. PHILOSOPHY

   The mailbot's philosophy is simple:

   o  The mailbot receives all of your incoming personal mail.

   o  You ALWAYS copy yourself on every message you send, so that the
      mailbot receives all of your outgoing personal mail.

   o  The mailbot performs six tasks, all optional:

      *  makes audit copies of your incoming and outgoing mail;

      *  performs duplicate supression;

      *  performs originator supression by rejecting messages from
         people who aren't your friends or on a guest list;

      *  performs content supression by rejecting messages that contain
         attachments with extensions on your prohibited list;

      *  sends a textual synopsis to your PDA; and,

      *  sends a copy to your remote mailbox.

   Do NOT use the personal.tcl mailbot if you receive mailing list
   traffic in your personal mailbox.  When sending mail to a mailing
   list, either:

   o  use a "From" address that the personal.tcl mailbot will process as
      "impersonal" mail, (e.g., "hewes+ietf.general@example.com"); or,

   o  set the "Reply-To" for the message to the mailing list.

   Consult Appendix A for information on how "impersonal" mail is
   identified and processed.















Rose                                                            [Page 3]

README                  The personal.tcl Mailbot           February 2002


2.1 Guest Lists

   Guest lists are an effective mechanism for cutting back on excessive
   mail.

   o  when the mailbot receives a message from you, it adds any
      recipients it finds to a permanent-guest list;

   o  when the mailbot receives a message from someone on a guest list,
      it adds any recipients it finds to a temporary-guest list; but,

   o  when the mailbot receives a message from someone not on any guest
      list, they get a rejection notice.

   Note that in order to promote someone to the permanent-guest list,
   you must send them a message (with a copy to yourself).  In most
   cases, simply replying to the original message accomplishes this.  Of
   course, if you don't want to promote someone to the permanent-guest
   list, simply remove that address (or your address) from the list of
   recipients in your reply.

   Here are the fine points:

   o  rejection notices contain a passphrase that may be used at most
      once to bypass the guest list mechanism (notices also contain the
      original message to minimize type-in by the uninvited);

   o  a flip-flop is used to avoid mail loops; and,

   o  messages originated by an administrative address (e.g.,
      "Postmaster") bypass the guest list mechanism (unless the message
      refers to a previously-rejected message, in which case it is
      supressed).

   The rejection notice should be written carefully to minimize an
   extreme negative reaction on the part of the uninvited.  Of course,
   by allowing a passphrase, this provides something of a CQ test for
   the uninvited -- if someone can't pass the test...













Rose                                                            [Page 4]

README                  The personal.tcl Mailbot           February 2002


3. BEHAVIOR

3.1 Arguments

   The mailbot supports the following command line arguments:

      -config configFile: specifies the name of the configuration file
      to use;

      -debug boolean: enables debug output;

      -file messageFile: specifies the name of the file containing the
      message;

      -originator orginatorAddress: specifies the email-address of the
      originator of the message; and,

      -user userName: specifies the user-identity of the recipient.

   Note that if "-user" is given, then the working directory is set to
   userName's home directory before configFile is sourced, and the umask
   is set defensively.

   The default values are:

       personal.tcl -config     .personal-config.tcl   \
                    -debug      0                      \
                    -file       -                      \
                    -originator "derived from message"

   Given the default values, only "-user" need be specified.  The reason
   is that if a message is being delivered to multiple local recipients,
   and if any of the ".forward" files are identical in content, then
   sendmail may not deliver the message to all of the local recipients.

   A few other (sendmail related) tips:

   o  If sendmail is configured with smrsh, you'll need to symlink
      personal.tcl into the /usr/libexec/sm.bin/ directory.

   o  Make sure that tclsh8.0 is in the path specified on the third-line
      of personal.tcl.

   o  You should chmod your ".forward" file to 0600.







Rose                                                            [Page 5]

README                  The personal.tcl Mailbot           February 2002


3.2 Actions

   The mailbot begins by parsing its arguments, sourcing configFile, and
   then examining the incoming message:

   1.  If auditInFile (Section 3.3.1.3) is set, a copy of the message is
       saved (Section 3.3.2.4) there.

   2.  If the message contains a previously-encountered "Message-ID",
       processing terminates.

   3.  If the message's originator can not be determined, a copy of the
       message is saved (Section 3.3.2.4) in the defaultMaildrop
       (Section 3.3.1.2) and processing terminates.

   4.  The originator's email-address is examined:

       1.  If the originator appears to be an automated administrative
           process (Section 3.3.2.1), and if a previously rejected
           email-address is found in the message, processing terminates.

       2.  Otherwise, if the originator isn't the user (Section
           3.3.2.3), or a friend (Section 3.3.2.2), or a permanent-
           access guest, or a temporary-access guest, and if noticeFile
           (Section 3.3.1.10) is set, then the message is rejected.

       3.  Otherwise, each recipient email-address in the message's
           header is added to a guest list.  (If the originator is the
           user (Section 3.3.2.3), the permanent-guest list is used
           instead of the temporary-guest list.)

   5.  If the originator is the the user (Section 3.3.2.3), then:

       1.  If auditOutFile (Section 3.3.1.4) is set, saved (Section
           3.3.2.4) there.

       2.  Regardless, processing terminates.

   6.  If pdaMailboxes (Section 3.3.1.11) is set, and if any plaintext
       is contained in the message, then the plaintext is sent to those
       email-addresses.

   7.  If remoteMailboxes (Section 3.3.1.12) is set, and if the message
       is successful resent to those email-addresses, then processing
       terminates.

   8.  A copy of the message is saved (Section 3.3.2.4) in the
       defaultMaildrop (Section 3.3.1.2) and processing terminates.



Rose                                                            [Page 6]

README                  The personal.tcl Mailbot           February 2002


3.3 The Configuration File

   There are two kinds of information that may be defined in configFile:
   configuration options (Section 3.3.1) and configurable procedures
   (Section 3.3.2).

   Here's a simple example of a configFile for a user named "example":

       set options(dataDirectory)   .personal
       set options(defaultMaildrop) /var/mail/example
       set options(logFile)         [file join .personal personal.log]
       set options(noticeFile)      [file join .personal notice.txt]


3.3.1 Configuration Options

   configFile must define dataDirectory (Section 3.3.1.1) and
   defaultMaildrop (Section 3.3.1.2).  All other configuration options
   are optional.

3.3.1.1 dataDirectory

   The directory where the mailbot keeps its databases.  The
   subdirectories are:

      badaddrs: the directory of rejected email-addresses

      inaddrs: the directory of originator email-addresses

      msgids: the directory of Message-IDs

      outaddrs: the permanent-guest list

      phrases: the directory of at-most-once passphrases

      tmpaddrs: the temporary-guest list

   If you want to remove someone from a guest list, simply go to that
   directory and delete the corresponding file.

3.3.1.2 defaultMaildrop

   The filename where messages are saved (Section 3.3.2.4) for later
   viewing by your user agent.

3.3.1.3 auditInFile

   The filename where messages are saved (Section 3.3.2.4) for audit



Rose                                                            [Page 7]

README                  The personal.tcl Mailbot           February 2002


   purposes.

3.3.1.4 auditOutFile

   The filename where your outgoing messages are saved (Section 3.3.2.4)
   for audit purposes.

3.3.1.5 dropNames

   A list of filename extensions for attachments that automatically
   cause the message to be rejected.

3.3.1.6 friendlyDomains

   A list used by friendP (Section 3.3.2.2) giving the domain names
   where your friends live.

3.3.1.7 friendlyfire

   If present and true, then someone sending a message both to you and
   someone you've previously sent mail to, is considered a friend.

3.3.1.8 logFile

   The filename where the mailbot logs (Section 3.3.2.8) its actions.

3.3.1.9 myMailbox

   Your preferred email-address with commentary text, e.g.,

       Arlington Hewes <hewes@example.com>


3.3.1.10 noticeFile

   The filename containing the textual notice sent when a message is
   rejected.  Note that all occurrances of "%passPhrase%" within this
   file are replaced with an at-most-once passphrase allowing the
   originator to bypass the mailbot's filtering.  Similarly, any
   occurrences of "%subject%" are replaced by the "Subject" of the
   incoming message.

3.3.1.11 pdaMailboxes

   The email-addresses where a textual synopsis of the incoming message
   is sent.





Rose                                                            [Page 8]

README                  The personal.tcl Mailbot           February 2002


3.3.1.12 remoteMailboxes

   The email-addresses where a copy of the incoming message is resent.
















































Rose                                                            [Page 9]

README                  The personal.tcl Mailbot           February 2002


3.3.2 Configurable Procedures

   All of these procedures are defined in personal.tcl.  You may
   override any of them in configFile.

3.3.2.1 adminP

       proc adminP {local domain}

   Returns "1" if the email-address is an automated administrative
   process.

3.3.2.2 friendP

       proc friendP {local domain}

   Returns "1" if the email-address is from a friendly domain (Section
   3.3.1.6) or sub-domain.

3.3.2.3 ownerP

       proc ownerP {local domain}

   Returns "1" if the email-address refers to the user (as determined by
   looking at myMailbox (Section 3.3.1.9), pdaMailboxes (Section
   3.3.1.11), and remoteMailboxes (Section 3.3.1.12).

3.3.2.4 saveMessage

       proc saveMessage {inF {outF ""}}

   Saves a copy of the message contained in the file inF.  If the
   destination file, outF, isn't specified, it defaults to the
   defaultMaildrop (Section 3.3.1.2).

3.3.2.5 findPhrase

       proc findPhrase {subject}

   Returns "1" if a previously-allocated passphrase is present in the
   subject.  If so, the passphrase is forgotten.

3.3.2.6 makePhrase

       proc makePhrase {}

   Returns an at-most-once passphrase for use with a rejection notice.




Rose                                                           [Page 10]

README                  The personal.tcl Mailbot           February 2002


3.3.2.7 pruneDir

       proc pruneDir {dir type}

   Removes old entries from one of the mailbot's databases (Section
   3.3.1.1).  The second parameter is one of "addr", "msgid", or
   "phrase".

3.3.2.8 tclLog

       proc tclLog {message}

   Writes a message to the logFile (Section 3.3.1.8).






































Rose                                                           [Page 11]

README                  The personal.tcl Mailbot           February 2002


References

   [1]  <http://core.tcl.tk/tcl/>

   [2]  <http://core.tcl.tk/tcllib/>

   [3]  <http://sourceforge.net/projects/tclx/>


Author's Address

   Marshall T. Rose
   Dover Beach Consulting, Inc.
   POB 255268
   Sacramento, CA  95865-5268
   US

   Phone: +1 916 483 8878
   Fax:   +1 916 483 8848
   EMail: mrose@dbc.mtview.ca.us































Rose                                                           [Page 12]

README                  The personal.tcl Mailbot           February 2002


Appendix A. Impersonal Mail

   If impersonalMail (Appendix A.2.1) returns a non-empty string then
   the message is processed differently than the algorithm given in
   Section 3.2.  Specifically:

   1.  If the message contains a previously-encountered "Message-ID",
       processing terminates.

   2.  If the message's originator can not be determined, processing
       terminates.

   3.  The value returned by impersonalMail (Appendix A.2.1) is the
       folder's name and is broken into one or more components seperated
       by dots (".").  If there aren't at least two components, or if
       any of the components are empty (e.g., the folder is named
       "sys..announce"), then the message is bounced.

   4.  If mappingFile (Appendix A.1.4) exists, that file is examined to
       see if an entry is present for the folder.  If so, the message is
       processed according to the value present, one of:

            "ignore": the message is silently ignored;

            "bounce": the message is noisily bounced; or,

           otherwise: the message is resent to the address.

       Regardless, if an entry was present for the folder, then
       processing terminates.

   5.  The message is saved (Section 3.3.2.4) in a file whose name is
       constructed by replacing each dot (".") in the folder name with a
       directory seperator (e.g., if the folder is named "sys.announce",
       then the file is called "announce" underneath the directory "sys"
       underneath the directory identified by foldersDirectory (Appendix
       A.1.1).

   6.  Finally, the file identified by foldersFile (Appendix A.1.2) is
       updated as necessary.











Rose                                                           [Page 13]

README                  The personal.tcl Mailbot           February 2002


A.1 Configuration Options

   If "impersonal" mail is received, then foldersFile (Appendix A.1.2)
   and foldersDirectory (Appendix A.1.1) must exist.

A.1.1 foldersDirectory

   The directory where the mailbot keeps private folders.

A.1.2 foldersFile

   This file contains one line for each private folder.

A.1.3 announceMailboxes

   The email-addresses where an announcement is sent when a new private
   folder is created.

A.1.4 mappingFile

   The file consulted by the mailbot to determine how to process
   "impersonal" messages.  Each line of the file consists of a folder
   name and value, seperated by a colon (":").  There are three reserved
   values: "bounce", "ignore", and "store".



























Rose                                                           [Page 14]

README                  The personal.tcl Mailbot           February 2002


A.2 Configurable Procedures

   All of these procedures are defined in personal.tcl.  You may
   override any of them in configFile.

A.2.1 impersonalMail

       proc impersonalMail {}

   If the message is deemed "impersonal", return the name of a
   corresponding private folder; otherwise, return the empty-string.

   Many mail systems have a mechanism of passing additional information
   when performing final delivery using a program.  With modern versions
   of sendmail, for example, if mail is sent to a local user named
   "user+detail", then, in the absense of an alias for either
   "user+detail" or "user+*", then the message is delivered to "user".
   The trick is to get sendmail to pass the "detail" part to the
   mailbot.

   At present, sendmail passes this information only if procmail is your
   local mailer.  Here's how I do it:

       *** _alias.c    Tue Dec 29 10:42:25 1998
       --- alias.c     Sat Sep 18 21:51:35 1999
       ***************
       *** 813,818 ****
       --- 813,821 ----
               define('z', user->q_home, e);
               define('u', user->q_user, e);
               define('h', user->q_host, e);
       +
       +       setuserenv("SUFFIX", user->q_host);
       +
               if (ForwardPath == NULL)
                       ForwardPath = newstr("\201z/.forward");

   This makes available an environment variable called "SUFFIX" which
   has the "details" part.  The drawback in this approach is that this
   information is lost if the message is re-queued for delivery (what's
   really needed is an addition to the .forward syntax to allow macros
   such as $h to be passed).









Rose                                                           [Page 15]

README                  The personal.tcl Mailbot           February 2002


   The corresponding impersonalMail procedure is defined as:

       proc impersonalMail {} {
           global env

           return $env(SUFFIX)
       }


A.2.2 processFolder

       proc processFolder {folderName mimeT} { return $string }

   If an entry for the folder exists in the mappingFile (Appendix
   A.1.4), and if the value for that entry is "process", then this
   procedure is invoked to return a string indicating what action to
   take (cf., Appendix A).


































Rose                                                           [Page 16]

README                  The personal.tcl Mailbot           February 2002


Appendix B. An Example configFile

   Here is the ".forward" file for the user "hewes":

       "|/usr/pkg/lib/mbot-1.1/personal.tcl
            -config .personal/config.tcl -user hewes"

   (Of course, it's all on one line.)

   Here is the user's ".personal/config.tcl" file:

       array set options [list                                          \
           dataDirectory     .personal                                  \
           defaultMaildrop   /var/mail/hewes                            \
           auditInFile       [file join .personal INCOMING]             \
           auditOutFile      [file join .personal OUTGOING]             \
           friendlyDomains   [list tcp.int example.com]                 \
           logFile           [file join .personal personal.log]         \
           myMailbox         "Arlington Hewes <hewes@example.com>"      \
           pdaMailboxes      hewes.pager@example.com                    \
           noticeFile        [file join .personal notice.txt]           \
           foldersDirectory  [file join .personal folders]              \
           foldersFile       [file join .personal .mailboxlist]         \
           announceMailboxes hewes+sys.announce@example.com             \
           mappingFile       [file join .personal mapping]              \
           friendlyFire      1                                          \
           dropNames         [list *.bat *.exe *.src *.pif *.wav *.vbs] \
       ]

       proc impersonalMail {} {
           global env

           return $env(SUFFIX)
       }

   Note that because remoteMailboxes (Section 3.3.1.12) isn't defined,
   personal messages are ultimately stored in the user's defaultMaildrop
   (Section 3.3.1.2).













Rose                                                           [Page 17]

README                  The personal.tcl Mailbot           February 2002


Appendix C. Acknowledgements

   The original version of this mailbot was written by the author in
   1994, implemented using  the safe-tcl package (Borenstein and Rose,
   circa 1993).














































Rose                                                           [Page 18]

