# -*- tcl -*-
package require    msgcat
namespace import ::msgcat::*

mcset de doctoc/char/syntax             {Unerwartetes Zeichen im String}
mcset de doctoc/cmd/illegal		{Illegaler Befehl "%1$s", ist kein doctoc Befehl}                 ; # Details: cmdname
mcset de doctoc/cmd/nested		{Illegale Nutzung von "%1$s" als Argument eines anderen Befehles} ; # Details: cmdname
mcset de doctoc/cmd/toomanyargs		{Zu viele Argumente fuer "%1$s", hoechstens %2$d moeglich}        ; # Details: cmdname, max#args
mcset de doctoc/cmd/wrongargs		{Zu wenig Argumente fuer "%1$s", mindestens %2$d notwendig}       ; # Details: cmdname, min#args
mcset de doctoc/eof/syntax              {Unerwartetes Ende der Datei}
mcset de doctoc/include/path/notfound	{Include-Datei "%1$s" nicht gefunden}                             ; # Details: file name
mcset de doctoc/include/read-failed	{Konnte Include-Datei "%1$s" nicht lesen: %2$s}                   ; # Details: file name and error msg
mcset de doctoc/include/syntax		{Fehler in der Include-Datei "%1$s"}
mcset de doctoc/plaintext		{Normaler Text ist (mit Ausnahme von reinem Leerraum) nicht erlaubt}
mcset de doctoc/vset/varname/unknown	{Unbekannte Variable "%1$s"}                                      ; # Details: variable name

mcset de doctoc/division_end/missing	{Erwarteter Befehl [division_end] nicht vorhanden}
mcset de doctoc/division_end/syntax	{[division_end] ist hier nicht erlaubt}
mcset de doctoc/division_start/syntax	{Erwarteter Befehl [division_start] nicht vorhanden}
mcset de doctoc/item/syntax		{[item] ist hier nicht erlaubt}
mcset de doctoc/toc_begin/missing	{Erwarteter Befehl [toc_begin] nicht vorhanden}
mcset de doctoc/toc_begin/syntax	{[toc_begin] ist hier nicht erlaubt}
mcset de doctoc/toc_end/missing		{Erwarteter Befehl [toc_end] nicht vorhanden}
mcset de doctoc/toc_end/syntax		{[toc_end] ist hier nicht erlaubt}

mcset de doctoc/redef                   {Fehlerhafte Wiederverwendung des Labels "%1$s"}

package provide doctools::msgcat::toc::de 0.1
