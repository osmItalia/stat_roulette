##Script di statistiche su database OSM ##
by Sbiribizio et al.

Gruppo di file in perl per generare le entry per MapRoulette 
a partire dai dati italiani in formato .osm


### CREDITS ###

Simone ha avuto l'idea.

I file originali in perl di Gary68 disponibili in [questa pagina](http://wiki.openstreetmap.org/wiki/User:Gary68 ).

Sabas ha contribuito con correzioni e la funzione di Haversine.

Christian ha realizzato tutti gli script in Python e molte funzioni aggiuntive.

Tutti gli errori di programmazione sono i miei o di Christian!



### INSTALLAZIONE ###

Per funzionare gli script hanno bisogno del linguaggio perl.

In aggiunta sono stati installati i seguenti oggetti


tramite apt-get :

- libdbd-sqlite3-perl
- sqlite3

`sudo apt-get install libdbd-sqlite3-perl sqlite3`


tramite CPAN:

- modulo Array::Utils
- modulo Compress::Bzip2 (o Compress::Raw::Bzip2)


Compress::Bzip2 è installabile anche con apt-get:
`sudo apt-get install libcompress-bzip2-perl`

Tramite copia a mano:

- in /usr/lib/perl5 va creata la directory OSM per contenere
   le librerie perl osm ; 
il contenuto della sottodirectory lib_OSM va copiato lì


Moduli python:
- geojson
sono installabili con `easy_install` o `pip`


### LE SOTTODIRECTORY ###

/tmp contiene dei file temporanei in formato testo per procedere all'import
     bulk di dati in sqlite


### PROCEDURA DI LAVORO ###

I file sono scaricati in formato .osm o .osm.bz2

Si genera il database SQLite col comando:

```bash
perl bulkDB.pl [file.osm | file.osm.bz2] database.sqlite
```

Si lanciano i vari controlli in perl su database.sqlite






