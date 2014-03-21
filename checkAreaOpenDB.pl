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
use Array::Utils qw(:all);

my @areas = qw (area:yes building:* landuse:*  waterway:riverbank leisure:park leisure:playground 
	amenity:hospital amenity:parking amenity:school amenity:university 
	natural:glacier natural:wood natural:water natural:scree natural:scrub natural:fell natural:heath natural:marsh natural:wetland);

#my @areas = qw (area:yes waterway:riverbank aeroway:terminal aeroway:apron building:* leisure:park leisure:playground 
#	amenity:bus_station amenity:college 
#	amenity:ferry_terminal amenity:hospital amenity:parking amenity:school amenity:university tourism:zoo tourism:museum
#	landuse:forest landuse:residential landuse:industrial landuse:cemetery natural:glacier natural:wood natural:water ) ;

#my @areas = qw (area:yes waterway:riverbank waterway:dock railway:turntable landuse:railway aeroway:terminal aeroway:apron 
#	aerialway:station power:station power:sub_station man_made:reservoir_covered man_made:surveillance 
#	man_made:wastewater_plant man_made:watermill man_made:water_works building:yes 
#	leisure:golf_course leisure:sports_center leisure:stadium leisure:track leisure:pitch leisure:water_park leisure:marina
#	leisure:fishing leisure:nature_reserve leisure:park leisure:playground leisure:garden leisure:common 
#	amenity:bicycle_parking amenity:bus_station amenity:car_rental amenity:car_sharing amenity:college 
#	amenity:ferry_terminal amenity:fountain amenity:hospital amenity:kindergarten amenity:parking amenity:place_of_worship
#	amenity:public_building amenity:school amenity:taxi amenity:townhall amenity:university amenity:verterinary
#	shop:kiosk shop:supermarket tourism:chalet tourism:camp_site tourism:caravan_site tourism:picnic_site tourism:theme_park
#	tourism:attraction tourism:zoo tourism:museum historic:archeological_site historic:ruins historic:battlefield historic:wreck
#	landuse:farm landuse:farm_yard landuse:quarry landuse:landfill landuse:basin landuse:reservoir landuse:forest
#	landuse:allotments landuse:residential landuse:retail landuse:commercial landuse:industrial landuse:brownfield landuse:greenfield
#	landuse:railway landuse:construction landuse:military landuse:cemetery landuse:meadow landuse:village_green 
#	landuse:recreation_ground military:airfield military:barracks military:danger_area military:range military:naval_base
#	natural:glacier natural:scree natural:scrub natural:fell natural:heath natural:wood natural:marsh natural:wetland
#	natural:water natural:mud natural:beach natural:bay natural:land natural:cave_entrance 
#	boundary:administrative boundary:civil boundary:political boundary:national_park
#	place:region place:county place:city place:town place:village place:hamlet place:suburb place:locality place:island) ;


my $program = "checkAreaOpenDB.pl" ;
my $version = "3.2" ;
my $usage = $program . " <file_db.sqlite> out.html out.txt" ;

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
my @nodeTags ;
my $aRef1 ;
my $aRef2 ;
my $aRef3 ;
my $aRef4 ;
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
my $txt ;
my $txtName ;


my @open ;
my @neededNodes ;
my %neededNodesHash ;
my %lon ;
my %lat ;
my %wayStart ;
my %wayEnd ;
my %openWayTags ;
my %openWayNodes ;
my %usedInRelation = () ;

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


#################################
# find all relation members first
#################################

print "INFO: pass1: parsing relations...\n" ;

my $null;

loopInitRelations ();

while ($relationId = loopGetNextRelation ) {
	($null, $aRef1, $aRef2) = getDBRelation($relationId);
	@relationMembers = @$aRef1 ;
	@relationTags = @$aRef2 ;

	#check all the ways that are in a relation
	foreach my $m (@relationMembers) {
		if ($m->[0] eq "way") { $usedInRelation{$m->[1]} = 1 ; }
		}
	}

print "INFO: done.\n" ;




#####################
# identify open areas
#####################

print "INFO: pass2: find open areas...\n" ;


######## OPTIMIZATION
#
# instead of selecting all ways and then check for tags
# select directly the ways with tag in @areas

foreach $tag2 (@areas) {
	my @tmp = split(/:/, $tag2);
	
	print "Cerco vie con tag @tmp\n";

	loopInitWays($tmp[0], $tmp[1]);

	while (	$wayId = loopGetNextWay ) {
		($null, $aRef1, $aRef2) = getDBWay($wayId);
       	 	@wayNodes = @$aRef1 ; #nodes are ordered 0,1,2, etc
       	 	@wayTags = @$aRef2 ;
	
#		my $found = 0 ;
#		my @tempTags= ();
	
#		foreach $tag1 ( @wayTags ) {
#			push @tempTags , $tag1->[0].':'.$tag1->[1];
#		    	}
	
#		if (intersect(@tempTags, @areas)) {
#				$found=1;
#				}
	
		$areaCount++ ;
		if ( ($wayNodes[0] != $wayNodes[-1]) and (! defined $usedInRelation{$wayId}) ) {
			$areaOpenCount ++ ;
			push @open, $wayId ;
			$wayStart{$wayId} = $wayNodes[0] ; 
			@{$openWayTags{$wayId}} = @wayTags ;
			@{$openWayNodes{$wayId}} = @wayNodes ;

			# I need only one node of the way
			($aRef3, $aRef4) = getDBWayNodesCoords($wayId);
			$nodeId = $wayNodes[0];
                        $lon{$nodeId} = $aRef3->{$nodeId};
                        $lat{$nodeId} = $aRef4->{$nodeId};

			}
		}
	}


print "INFO: number open areas: $areaOpenCount\n" ;



$time1 = time () ;


######################
# PRINT HTML INFOS
######################
print "\nINFO: write HTML tables...\n" ;


open ($html, ">", $htmlName) || die ("Can't open html output file") ;

printHTMLHeader ($html, "$program") ;

print $html "<H1>$program</H1>\n" ;
print $html "<p>Version ", $version, "</p>\n" ;

print $html "<p>Check ways with following tags:</p>\n" ;
print $html "<p>" ;
foreach (@areas) {
	print $html $_, " " ;
}
print $html "</p>" ;



print $html "<H2>Statistics</H2>\n" ;
print $html "number open areas: $areaOpenCount</p>\n" ;


print $html "<H2>Open Areas</H2>\n" ;
print $html "<p>These ways have to be closed areas according to map features but the first node is not the same as the last. So area is probably not closed or not properly so. It is possible that parts of the way are drawn doubly (thus closing the area in a way).</p>" ;
print $html "<table border=\"1\" width=\"100%\">\n";
print $html "<tr>\n" ;
print $html "<th>Line</th>\n" ;
print $html "<th>WayId</th>\n" ;
print $html "<th>Tags</th>\n" ;
print $html "<th>Nodes</th>\n" ;
#print $html "<th>Distance start/end</th>\n" ;
print $html "<th>start node id</th>\n" ;
print $html "<th>OSM</th>\n" ;
print $html "<th>JOSM</th>\n" ;
print $html "</tr>\n" ;
$i = 0 ;
foreach $wayId (@open) {
	$i++ ;

	print $html "<tr>\n" ;
	print $html "<td>", $i , "</td>\n" ;
	print $html "<td>", historyLink ("way", $wayId) , "</td>\n" ;

	print $html "<td>" ;
	foreach (@{$openWayTags{$wayId}}) { 
		print $html @$_[0],'=', @$_[1], " - " ;
		}
	print $html "</td>\n" ;

	print $html "<td>" ;
	foreach (@{$openWayNodes{$wayId}}) { print $html $_, " - " ; }
	print $html "</td>\n" ;

	#my $dist = distance ($lon{$wayStart{$wayId}},$lat{$wayStart{$wayId}},$lon{$wayEnd{$wayId}},$lat{$wayEnd{$wayId}}) * 1000 ;
	#printf $html "<td>%.0f m</td>\n", $dist ;

	print $html "<td>", $wayStart{$wayId}, "</td>\n" ;
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
foreach $wayId (@open) {
        print $txt "ARE_$wayId\n";
        }

close ($txt) ;




print "\nINFO: finished after ", stringTimeSpent ($time1-$time0), "\n\n" ;


