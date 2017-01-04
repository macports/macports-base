# -*- tcl -*-
package require    msgcat
namespace import ::msgcat::*

mcset de docidx/char/syntax             {Unerwartetes Zeichen im String}
mcset de docidx/cmd/illegal		{Illegaler Befehl "%1$s", ist kein docidx Befehl}                 ; # Details: cmdname
mcset de docidx/cmd/nested		{Illegale Nutzung von "%1$s" als Argument eines anderen Befehles} ; # Details: cmdname
mcset de docidx/cmd/toomanyargs		{Zu viele Argumente fuer "%1$s", hoechstens %2$d moeglich}        ; # Details: cmdname, max#args
mcset de docidx/cmd/wrongargs		{Zu wenig Argumente fuer "%1$s", mindestens %2$d notwendig}       ; # Details: cmdname, min#args
mcset de docidx/eof/syntax              {Unerwartetes Ende der Datei}
mcset de docidx/include/path/notfound	{Include-Datei "%1$s" nicht gefunden}                             ; # Details: file name
mcset de docidx/include/read-failed	{Konnte Include-Datei "%1$s" nicht lesen: %2$s}                   ; # Details: file name and error msg
mcset de docidx/include/syntax		{Fehler in der Include-Datei "%1$s"}
mcset de docidx/plaintext		{Normaler Text ist (mit Ausnahme von reinem Leerraum) nicht erlaubt}
mcset de docidx/vset/varname/unknown	{Unbekannte Variable "%1$s"}                                      ; # Details: variable name

mcset de docidx/index_begin/missing	{Erwarteter Befehl [index_begin] nicht vorhanden}
mcset de docidx/index_begin/syntax	{[index_begin] ist hier nicht erlaubt}
mcset de docidx/index_end/missing	{Erwarteter Befehl [index_end] nicht vorhanden}
mcset de docidx/index_end/syntax	{[index_end] ist hier nicht erlaubt}
mcset de docidx/key/missing		{Erwarteter Befehl [key] nicht vorhanden}
mcset de docidx/key/syntax		{[key] ist hier nicht erlaubt}

mcset de docidx/ref/redef               {Fehlerhafte Verwendung der Referenz "%1$s", zuerst (%2$s "%3$s"), jetzt (%4$s "%5$s")}

package provide doctools::msgcat::idx::de 0.1
