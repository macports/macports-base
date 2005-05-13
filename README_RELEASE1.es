--------------------------------------------------------------------------
Notas cortas acerca de la instalacion y uso de DarwinPorts 1.0.
--------------------------------------------------------------------------

DarwinPorts se instala al ejecutar:

	./configure && make && sudo make install

Esto colocara una instalacion estandard de DarwinPorts en /opt/local. El usuario
debera asegurarse que /opt/local/bin se encuentre en su variable de entorno
PATH, de lo contrario el shell no podra encontrar los ejecutables que son instalados
por DarwinPorts.

Si esta usando un shell de tipo bourne (Panther y Tiger usan bash por defecto),
agregue la siguiente linea a su documento ~/.profile. Si el documento no existe,
creelo.

	export PATH=/opt/local/bin:$PATH

Si esta usando un shell tipo (t)csh (Jaguar), agregue la siguente linea a su documento
~/.cshrc. Si el documento no existe, creelo. Sus cambios no tomaran efecto hasta que
no abra un nuevo shell.

	set path=(/opt/local/bin $path)

Finalmente, debe bajar los documentos con las descripciones de los portes, los Portfiles:

	port sync

Si desea actualizar los Portfiles y la infraestructura de DarwinPorts (base), ejecute:

	sudo port selfupdate

NOTAS CORTAS

Para buscar un porte y/o relacionados, "vi" por ejemplo:

	port search vi

Para instalar un porte:

	sudo port install <nombre>

Por favor lea el manual del comando port:

	man port

Tambien hay manuales para portfile, porthier y portstyle, orientados hacia escritores de Portfiles.

Consulte la guia en linea (actualmente solo en Ingles):

	http://darwinports.opendarwin.org/guide

Visite la lista de correo de usuarios de DarwinPorts:

        http://opendarwin.org/mailman/listinfo/darwinports

Reporte errores (bugs):

	http://bugzilla.opendarwin.org/
