#
# Check Sabas buildings
#
# trova tutti le relation di tipo multipolygon che hanno la chiave building sia sulla relazione che sulla way outer


use strict ;
use warnings ;

use OSM::osm 4.9 ;
use OSM::osmDB_SQLite ;
use Array::Utils qw(:all);


my $program = "checkSabasBuildings.pl" ;
my $version = "1" ;
my $usage = $program . " <file_db.sqlite> out.html out.txt" ;

my $wayId ;
my @wayNodes ;
my @wayTags ;
my $nodeId ;
my $nodeLat ;
my $nodeLon ;
my @nodeTags ;
my $aRef1 ;
my $aRef2 ;
my $aRef3 ;
my $aRef4 ;
my $aRef5 ;
my $aRef6 ;
my $relationId ;
my @relationMembers ;
my @relationTags ;

my $wayCount = 0 ;
my $areaCount = 0 ;
my $areaOpenCount = 0 ;

my $time0 = time() ; my $time1 ;
my $i ;
my $key ;
my $num ;
my $tag1 ; my $tag2 ;

my $APIcount = 0 ;
my $APIerrors = 0 ;
my $APIrejected = 0 ;

my $html ;
my $dbName ;
my $htmlName ;


my @open ;
my @neededNodes ;
my %neededNodesHash ;
my $lon ;
my $lat ;


###############
# get parameter
###############
$dbName = shift||'';
if (!$dbName)
{
	die (print $usage, "\n");
}

$htmlName = shift||'';
if (!$htmlName)
{
	die (print $usage, "\n");
}



print "\n$program $version for file $dbName\n\n" ;


######################
# open DB
######################
my @parametri = ($dbName, '', '');
dbConnect @parametri;


open ($html, ">", $htmlName) || die ("Can't open html output file") ;

printHTMLHeader ($html, "$program") ;

print $html "<H1>$program</H1>\n" ;

print $html "<p>Check relation con il tag \"building\" nella relation e nei membri</p>\n" ;

print $html "<table border=\"1\" width=\"100%\">\n";
print $html "<tr>\n" ;
print $html "<th>Line</th>\n" ;
print $html "<th>relation Id</th>\n" ;
print $html "<th>way Id</th>\n" ;
print $html "<th>role</th>\n" ;
print $html "<th>tag trovato</th>\n" ;
print $html "<th>JOSM</th>\n" ;
print $html "</tr>\n" ;


print "INFO: pass1: parsing relations...\n" ;

my $null;
$i = 0 ;

loopInitRelations ('building','*');

while ($relationId = loopGetNextRelation ) {
	($null, $aRef1, $aRef2) = getDBRelation($relationId);
	@relationMembers = @$aRef1 ;
	@relationTags = @$aRef2 ;

	#check all the ways that are in a relation
	foreach my $m (@relationMembers) {

		if ($m->[0] eq "way") { 
			#check se hanno building=*
			$wayId = $m->[1];
			($null, $aRef3, $aRef4) = getDBWay($wayId) ; 
       	 		@wayNodes = @$aRef3 ; 
       	 		@wayTags = @$aRef4 ;
			foreach (@wayTags) {
	 			if ( $_->[0] eq "building") {
					#carico lat e lon del primo nodo della way
					($aRef5, $aRef6) = getDBWayNodesCoords($wayId);
					$lon = $aRef5->{$wayNodes[0]};	
					$lat = $aRef6->{$wayNodes[0]};	

					#stampo perche' ho trovato
					$i++;

					print $html "<tr>\n" ;
					print $html "<td>", $i , "</td>\n" ;
					print $html "<td>", historyLink ("relation", $relationId) , "</td>\n" ;
					print $html "<td>", historyLink ("way", $wayId) , "</td>\n" ;
					print $html "<td>$m->[2]</td>\n" ;
					print $html "<td>$_->[0]=$_->[1]</td>\n" ;
					print $html "<td>", josmLink ($lon, $lat, 0.0005, $wayId), "</td>\n" ;
					print $html "</tr>\n";
 					}
				}	
			}
		}	
	}

print "INFO: done.\n" ;

$time1 = time () ;


print $html "</table>\n" ;
print $html "<p>$i lines total</p>\n" ;



########
# FINISH
########
print $html "<p>", stringTimeSpent ($time1-$time0), "</p>\n" ;
printHTMLFoot ($html) ;

close ($html) ;


print "\nINFO: finished after ", stringTimeSpent ($time1-$time0), "\n\n" ;


