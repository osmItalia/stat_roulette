#
# areacheck by gary68
#
#
#
#
# Copyright (C) 2008, 2009, Gerhard Schwanz
#
# This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the 
# Free Software Foundation; either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program; if not, see <http://www.gnu.org/licenses/>
#
#
# 1.0 B 003
# - added lots of tags
#
# 1.0 B 004
#
# 1.0 B 005
# - hash get node info
# - additional gpx output
#
# 1.1
# - add more links to HTML
#
# 3.0
# - online api support
#
# 3.2
# - check if way is part of relation, then omit
#

use strict ;
use warnings ;

use OSM::osm 4.9 ;
use OSM::osmDB_SQLite ;
use Math::Trig ;
use Array::Utils qw(:all);
use POSIX;

my @areas = qw ( leisure:playground leisure:pitch );


my $program = "checkBigAreaDB.pl" ;
my $version = "3.2" ;
my $usage = $program . " <dimension in square meters> <file_db.sqlite> out.html out.txt" ;

my $wayId ;
my $wayId2 ;
my $wayUser ;
my @wayNodes ;
my @wayTags ;
my $nodeId ;
my $nodeId2 ;
my $nodeUser ;
my $nodeLat ;
my $nodeLon ;
my %areaDim ;
my $aRef1 ;
my $aRef2 ;
my $aRef3 ;
my $aRef4 ;

my $wayCount = 0 ;
my $areaCount = 0 ;
my $biggerAreaCount = 0 ;

my $time0 = time() ; my $time1 ;
my $i ; my $j ;
my $key ;
my $num ;
my $tag1 ; my $tag2 ;

my $html ;
my $dbName ;
my $htmlName ;
my $txt ;
my $txtName ;

my $maxDimension ;
my @bigger ;
my %lon ;
my %lat ;
my %wayStart ;
my %wayEnd ;
my %biggerWayTags ;
my %biggerWayNodes ;

###############
# get parameter
###############
$maxDimension = shift||'';
if (!$maxDimension)
{
	die (print $usage, "\n");
}

$dbName = shift||'';
if (!$dbName)
{
	die (print $usage, "\n");
}

$htmlName = shift||'';
if (!$htmlName)
{
	die (print $usage, "\n")

;
}

$txtName = shift||'';
if (!$txtName)
{
	die (print $usage, "\n");
}


print "\n$program $version for file $dbName\n\n" ;
print "\n" ;
print "Check areas:\n" ;

foreach (@areas) {
	print $_, " " ;
}
print "\n\n" ;


######################
# open DB
######################
my @parametri = ($dbName, '', '');
dbConnect @parametri;


#####################
# identify closed areas
#####################

print "INFO: pass: find dimension of  areas...\n" ;


######## OPTIMIZATION
#
# instead of selecting all ways and then check for tags
# select directly the ways with tag in @areas

foreach $tag2 (@areas) {
	my @tmp = split(/:/, $tag2);
	
	print "Cerco vie con tag @tmp\n";

	loopInitWays($tmp[0], $tmp[1]);

	my $null;

	while (	$wayId = loopGetNextWay ) {
		($null, $aRef1, $aRef2) = getDBWay($wayId);
       	 	@wayNodes = @$aRef1 ; #nodes are ordered 0,1,2, etc
       	 	@wayTags = @$aRef2 ;
	
		$areaCount++ ;
		# la way e' chiusa ed ha piu' di 2 nodi
		if ( ($wayNodes[0] == $wayNodes[-1]) and (scalar @wayNodes > 2)) {

			($aRef3, $aRef4) = getDBWayNodesCoords($wayId);
			
			# computo l'area
			my $area = 0;

			my $maxnodes = $j =  (scalar  @wayNodes) -1 ;
			for ($i=0; $i < $maxnodes; $i++) {
				my $id_i =  $wayNodes[$i];
				my $id_j =  $wayNodes[$j];
              		        $lon{$id_i} = $aRef3->{$id_i};
               		        $lat{$id_i} = $aRef4->{$id_i};
              		        $lon{$id_j} = $aRef3->{$id_j};
               		        $lat{$id_j} = $aRef4->{$id_j};
				# alcuni nodi non hanno coordinate
				# se li trovo, salto il computo e azzero
				if ( $lon{$id_i} &&  $lat{$id_i} && $lon{$id_j} &&  $lat{$id_j}) {
					$area = $area + haversine ($lat{$id_i},  $lon{$id_i}, $lat{$id_j},  $lon{$id_i}) *  haversine ( $lat{$id_i}, $lon{$id_i},  $lat{$id_i}, $lon{$id_j}) ;
					}
				else { $area = -1; }

				$j = $i;
				}
			$area = $area / 2;

			if ($area > $maxDimension) {
#print "Big Area: " . floor($area) ." mq\n";
				push @bigger, $wayId;
				@{$biggerWayTags{$wayId}} = @wayTags ;
				@{$biggerWayNodes{$wayId}} = @wayNodes ;
				$wayStart{$wayId} = $wayNodes[0];
				$biggerAreaCount ++ ;
				$areaDim{$wayId} = floor($area);
				}
			}
		}
	}


print "INFO: number biggerareas: $biggerAreaCount\n" ;



$time1 = time () ;


######################
# PRINT HTML INFOS
######################
print "\nINFO: write HTML tables...\n" ;


open ($html, ">", $htmlName) || die ("Can't open html output file") ;

printHTMLHeader ($html, "$program") ;

print $html "<H1>$program</H1>\n" ;
print $html "<p>Version ", $version, "</p>\n" ;

print $html "<p>Check areas with following tags:</p>\n" ;
print $html "<p>" ;
foreach (@areas) {
	print $html $_, " " ;
}
print $html "</p>" ;



print $html "<H2>Statistics</H2>\n" ;
print $html "number bigger areas: $biggerAreaCount</p>\n" ;


print $html "<H2>Big Areas</H2>\n" ;
print $html "<p>These ways seems bigger than <b>$maxDimension square meters.</b></p>" ;
print $html "<table border=\"1\" width=\"100%\">\n";
print $html "<tr>\n" ;
print $html "<th>Line</th>\n" ;
print $html "<th>WayId</th>\n" ;
print $html "<th>Tags</th>\n" ;
print $html "<th>Dimension</th>\n" ;
print $html "<th>OSM</th>\n" ;
print $html "<th>JOSM</th>\n" ;
print $html "</tr>\n" ;
$i = 0 ;

foreach $wayId (@bigger) {
	$i++ ;

	print $html "<tr>\n" ;
	print $html "<td>", $i , "</td>\n" ;
	print $html "<td>", historyLink ("way", $wayId) , "</td>\n" ;

	print $html "<td>" ;
	foreach (@{$biggerWayTags{$wayId}}) { 
		print $html @$_[0],'=', @$_[1], " - " ;
		}
	print $html "</td>\n" ;

	print $html "<td> $areaDim{$wayId} square meters</td>\n" ;

	print $html "<td>", osmLink ($lon{$wayStart{$wayId}}, $lat{$wayStart{$wayId}}, 16) , "</td>\n" ;
	print $html "<td>", josmLink ($lon{$wayStart{$wayId}}, $lat{$wayStart{$wayId}}, 0.01, $wayId), "</td>\n" ;

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
foreach $wayId (@bigger) {
        print $txt "BIG_$wayId\n";
        }

close ($txt) ;




print "\nINFO: finished after ", stringTimeSpent ($time1-$time0), "\n\n" ;

# ----------------- subfunctions

sub haversine
{
my($lat1,$lon1,$lat2,$lon2)=@_;
    my $R = 6372797.560856;

    my $dlat = deg2rad($lat2-$lat1);
    my $dlon = deg2rad($lon2-$lon1);

	my $lonh=sin($dlon*0.5);
	$lonh *= $lonh;
	
	my $lath=sin($dlat*0.5);
	$lath *= $lath;

	my $tmp= cos(deg2rad($lat1))*cos(deg2rad($lat2));

    my $res= 2*$R*asin_real(sqrt($lath+$tmp*$lonh));
	return $res;
}




