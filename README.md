##Script di statistiche su database OSM ##
by Sbiribizio et al.

Gruppo di file in perl per generare le entry per MapRoulette 
a partire dai dati italiani in formato .osm


### CREDITS ###

Simone ha avuto l'idea.

I file originali in perl di Gary68 disponibili in [questa pagina](http://wiki.openstreetmap.org/wiki/User:Gary68 ).

Sabas ha contribuito con correzioni e la funzione di Haversine.

Tutti gli errori di programmazione sono i miei!



### INSTALLAZIONE ###

Per funzionare gli script hanno bisogno del linguaggio perl.

In aggiunta sono stati installati i seguenti oggetti



tramite apt-get :

- libdbd-sqlite3-perl
- sqlite 3



tramite CPAN:

- modulo Array::Utils
- modulo Compress::Bzip2


Tramite copia a mano:

- in /usr/lib/perl5 va creata la directory OSM per contenere
   le librerie perl osm ; 
il contenuto della sottodirectory lib_OSM va copiato li'




### LE SOTTODIRECTORY ###

/tmp contiene dei file temporanei in formato testo per procedere all'import
     bulk di dati in sqlite


### PROCEDURA DI LAVORO ###

I file sono scaricati in formato .osm o .osm.bz2

Si genera il database SQLite col comando:

> perl bulkDB.pl [file.osm | file.osm.bz2] database.sqlite

Si lanciano i vari controlli in perl su database.sqlite






