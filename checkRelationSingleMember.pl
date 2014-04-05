#
# check if a relation has 1 member
#

use strict ;
use warnings ;

use OSM::osm 4.9 ;
use OSM::osmDB_SQLite ;


my $program = "checkRelationSingleMember.pl" ;
my $version = "1.0" ;
my $usage = $program . " <file_db.sqlite> out.html out.txt" ;


my $time0 = time() ; my $time1 ;
my $i ;
my $key ;
my $num ;

my $dbhandler;

my $dbName ;
my $htmlName;
my $txtName ;
my $html ;
my $txt ;
my $lon ;
my $lat ;
my $aRef1 ;
my $aRef2 ;

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

$txtName = shift||'';
if (!$txtName)
{
	die (print $usage, "\n");
}


print "\n$program $version for file $dbName\n\n" ;
print "\n" ;


######################
# open DB
######################
my @parametri = ($dbName, '', '');
$dbhandler = dbConnect @parametri;




#################################
# find all relation  with 1 member
#################################

print "INFO: pass1: parsing relations...\n" ;


my $query =  "select m.id,m.type,m.memberid,v  from relationmembers as m, relationtags as t where m.id=t.id and k='type'  group by m.id having count(m.id) = 1 ";

my $sth = $dbhandler->prepare($query) or die "Couldn't prepare statement: " . $dbhandler->errstr ;
$sth->execute() or die "Couldn't execute statement: " . $sth->errstr ;





print "INFO: done.\n" ;




$time1 = time () ;


######################
# PRINT HTML INFOS
######################
print "\nINFO: write HTML tables...\n" ;


open ($html, ">", $htmlName) || die ("Can't open html output file") ;

printHTMLHeader ($html, "$program") ;

print $html "<H1>$program</H1>\n" ;
print $html "<p>Version ", $version, "</p>\n" ;


print $html "<table border=\"1\" width=\"100%\">\n";
print $html "<tr>\n" ;
print $html "<th>Line</th>\n" ;
print $html "<th>Relation</th>\n" ;
print $html "<th>Relation Type</th>\n" ;
print $html "<th>Member</th>\n" ;
print $html "<th>Member Type</th>\n" ;
print $html "<th>OSM</th>\n" ;
print $html "<th>JOSM</th>\n" ;
print $html "</tr>\n" ;
$i = 0 ;
my @data ;

while (@data = $sth->fetchrow_array()) {
#	 print "$data[0] $data[1] $data[2] $data[3] $data[4]\n" ;
	$i++ ;

	print $html "<tr>\n" ;
	print $html "<td>", $i , "</td>\n" ;
	print $html "<td>", historyLink ("relation", $data[0]) , "</td>\n" ;

	print $html "<td>" ,  $data[3] ,  "</td>\n";

	print $html "<td>", historyLink ($data[1], $data[2]) , "</td>\n" ;
	print $html "<td>" ,  $data[1] ,  "</td>\n";

	$lat = $lon =0;

	if ($data[1] eq 'way') {
		($aRef1, $aRef2) = getDBWayNodesCoords($data[2]);
		 $lon= (values $aRef1)[0];
                 $lat= (values $aRef2)[0];
		}

	if ($data[1] eq 'node') {
		($aRef1, $aRef2) = getDBNode($data[2]);
		$lon = $aRef1->{'lon'};
		$lat = $aRef1->{'lat'};
		}
	print $html "<td>", osmLink ($lon, $lat, 16) , "</td>\n" ;
	
	if ($data[1] eq 'way') {
		print $html "<td>", josmLinkSelectWay ($lon, $lat, 0.0005, $data[2]), "</td>\n" ;
		}
	else {
		if ($data[1] eq 'node') {
			print $html "<td>", josmLinkSelectNode ($lon, $lat, 0.0005, $data[2]), "</td>\n" ;
	 		}
		else {
			print $html "<td> </td>\n" ;
			}
		}

	print $html "</tr>\n" ;
}

print $html "</table>\n" ;
print $html "<p>$i lines total</p>\n" ;



########
# FINISH
########
print $html "<p>", stringTimeSpent ($time1-$time0), "</p>\n" ;
printHTMLFoot ($html) ;

close ($html) ;


##############
# print tasks on file
##############

open ($txt, ">", $txtName) || die ("Can't open txt output file") ;
#foreach $wayId (@open) {
#	my $outputString = "";
#        $outputString = "ARE_$wayId ";
#	foreach (@{$openWayNodes{$wayId}}) { 
#		$outputString .= "[".$lon{$_}. ",".$lat{$_}."],"; 
#		}
#	#tolgo ultima virgola
#	chop($outputString);
#	print $txt "$outputString\n";
#        }

close ($txt) ;


print "\nINFO: finished after ", stringTimeSpent ($time1-$time0), "\n\n" ;


