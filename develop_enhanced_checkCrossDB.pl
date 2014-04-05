# 
#
# checkcross.pl by gary68
#
# this program checks an osm file for crossing ways which don't share a common node at the intersection and are on the same layer
#
#
# Copyright (C) 2008, Gerhard Schwanz
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
# example definition file:
# (IMPORTANT: don't enter a tag in both sections!)
#
#<XML>
#  <k="check" v="highway:motorway">
#  <k="check" v="highway:motorway_link">
#  <k="check" v="highway:trunk">
#  <k="check" v="highway:trunk_link">
#  <k="against" v="highway:primary">
#  <k="against" v="highway:primary_link">
#  <k="against" v="highway:secondary">
#  <k="against" v="highway:tertiary">
#  <k="against" v="junction:roundabout">
#</XML>
#
# Version 1.0
#
# Version 1.1
# - don't consider short oneways (false positives in large intersections)
#
# Version 1.2
# - stat
#
# Version 1.3
# - stat 2
#
# Version 1.4
# - select both ways in josm
#
# Version 1.5
# - get bugs implemented
#
# Version 1.6
# - get bugs NEW OSB additionally implemented
# - gpx file with open bugs for germany can be obtained here: http://openstreetbugs.schokokeks.org/api/0.1/getGPX?b=47.4&t=55.0&l=5.9&r=15.0&limit=100000&open=yes
# - added map compare link
#
# Version 2.0
# - faster execution parameters
#
#
# Version 3.0
# - quad trees
#
# Version 3.1
# - sorted output
#

# version enhancement
#
# Mantenere un elenco delle way gia' controllate con il numero di versione
# se 2 way gia' controllate continuano ad avere lo stesso numero di versione
# (= non sono state toccate) allora salta la ricerca degli incroci, riproponendo quelli gia' trovati


use strict ;
use warnings ;

use List::Util qw[min max] ;
use OSM::osm 5.1 ;
use OSM::osmDB_SQLite ;
use OSM::QuadTree ;
use File::stat;
use Time::localtime;
#use LWP::Simple;

my $olc = 0 ;

my $program = "checkCrossDB.pl" ;
my $usage = $program . " def.xml file.sqlite out.htm out.txt" ;
my $version = "3.1" ;
my $mode = "N" ; #mode Normal

my $bugsMaxDist = 0.05 ; # in km
my $bugsDownDist = 0.02 ; # in deg
#my $minLength = 100 ; # min length of way to be considered in result list (in meters)


my $qt ;

my $wayId ; my $wayId1 ; my $wayId2 ;
my $wayUser ; my @wayNodes ; my @wayTags ;
my $nodeId ; 
my $nodeUser ; my $nodeLat ; my $nodeLon ; my @nodeTags ;
my $aRef1 ; my $aRef2 ; my $aRef3 ; my $aRef4 ;
my $wayCount = 0 ;
my $againstCount = 0 ;
my $checkWayCount = 0 ;
my $againstWayCount = 0 ;
my $invalidWays = 0 ;

my @check ;
my @against ;
my @checkWays ;
my @againstWays ;

my $time0 = time() ; my $time1 ; my $timeA ;
my $i ; my $x ;
my $key ;
my $num ;
my $tag ; my $tag1 ; my $tag2 ;
my $progress ;
my $potential ;
my $checksDone ;

my $html ;
my $def ;
my $txt ;
my $txtName ;
my $htmlName ;
my $defName ;
my $dbName ;

my %wayNodesHash ;
my @neededNodes ;
my %lon ; my %lat ;
my %xMax ; my %xMin ; my %yMax ; my %yMin ; 
my %layer ;
my %wayCategory ;
my %wayHash ;
my %length ;
my %oneway ;

my $crossings = 0 ;
my %crossingsHash ;

###############
# get parameter
###############

$defName = shift||'';
if (!$defName)
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
	die (print $usage, "\n");
}

$txtName = shift||'';
if (!$txtName)
{
	die (print $usage, "\n");
}

print "\n$program $version for file $dbName\n\n" ;


##################
# read definitions
##################

print "read definitions file $defName...\n" ;
open ($def, , "<", $defName) or die "definition file $defName not found" ;

while (my $line = <$def>) {
	#print "read line: ", $line, "\n" ;
	my ($k)   = ($line =~ /^\s*<k=[\'\"]([:\w\s\d]+)[\'\"]/); # get key
	my ($v) = ($line =~ /^.+v=[\'\"]([:\w\s\d]+)[\'\"]/);       # get value
	
	if ($k and defined ($v)) {
		#print "key: ", $k, "\n" ;
		#print "val: ", $v, "\n" ;

		if ($k eq "check") {
			push @check, $v ;
		}
		if ($k eq "against") {
			push @against, $v ;
		}
	}
}

close ($def) ;



print "Check ways: " ;
foreach (@check) { print $_, " " ;} print "\n" ;
print "Against: " ;
foreach (@against) { print $_, " " ;} print "\n\n" ;





######################
# open DB
######################
my @parametri = ($dbName, '', '');
dbConnect @parametri;


#############################
# identify check/against ways
#############################
print "pass1: identify check ways...\n" ;

my $null;


my $minLon = 999 ;
my $maxLon = -999 ;
my $minLat = 999 ;
my $maxLat = -999 ;

######## OPTIMIZATION
#
# instead of selecting all ways and then check for tags
# select directly the ways with tag in @check and @against


foreach $tag (@check) {
	my @tmp = split(/:/, $tag);
	
	print "Check -> Cerco vie con tag @tmp\n";
	
	loopInitWays($tmp[0], $tmp[1]);
	
	 while ( $wayId = loopGetNextWay ) {
                ($null, $aRef1, $aRef2) = getDBWay($wayId);
                @wayNodes = @$aRef1 ; #nodes are ordered 0,1,2, etc
                @wayTags = @$aRef2 ;

	       	$wayCount++ ;
        	if (scalar (@wayNodes) >= 2) {

      	 	         my $layerTemp = "0" ; my $onewayTemp = 0 ;
       		         # check tags ONLY ONCE
       		         foreach $tag1 (@wayTags) {
       	                 if ($tag1->[0] eq 'layer') { $layerTemp =$tag1->[1] ; }
				}
			push @checkWays, $wayId ; 
			$checkWayCount++ ;
			$layer{$wayId} = $layerTemp ;
			$oneway{$wayId} = $onewayTemp ;
			$wayCategory{$wayId} = 1 ;

			($aRef3, $aRef4) = getDBWayNodesCoords($wayId);
			
			for( $x =0; $x < scalar (@wayNodes); $x++) {
				$nodeId = $wayNodes[$x];
                                $nodeLon = $aRef3->{$nodeId};
                                $nodeLat = $aRef4->{$nodeId};

				if ($nodeLon && $nodeLat) {   #some nodes can be out of region
                                	$lon{$nodeId} = $aRef3->{$nodeId};
                                	$lat{$nodeId} = $aRef4->{$nodeId};
					push @{$wayNodesHash{$wayId}}, $nodeId;
					if ($nodeLon > $maxLon) { $maxLon = $nodeLon ; }
					if ($nodeLon < $minLon) { $minLon = $nodeLon ; }
					if ($nodeLat > $maxLat) { $maxLat = $nodeLat ; }
					if ($nodeLat < $minLat) { $minLat = $nodeLat ; }
					}
				}
		}
	}
}

foreach $tag (@against) {
	my @tmp = split(/:/, $tag);
	
	print "Against -> Cerco vie con tag @tmp\n";
	
	loopInitWays($tmp[0], $tmp[1]);
	
	 while ( $wayId = loopGetNextWay ) {
                ($null, $aRef1, $aRef2) = getDBWay($wayId);
                @wayNodes = @$aRef1 ; #nodes are ordered 0,1,2, etc
                @wayTags = @$aRef2 ;

	       	$wayCount++ ;
        	if (scalar (@wayNodes) >= 2) {

      	 	         my $layerTemp = "0" ; my $onewayTemp = 0 ;
       		         # check tags ONLY ONCE
       		         foreach $tag1 (@wayTags) {
       	                 if ($tag1->[0] eq 'layer') { $layerTemp =$tag1->[1] ; }
       	                 	}
       		        push @againstWays, $wayId ;
			$againstWayCount++ ;
   	                $layer{$wayId} = $layerTemp ;
       		        $oneway{$wayId} = $onewayTemp ;
       		        $wayCategory{$wayId} = 2 ;

			($aRef3, $aRef4) = getDBWayNodesCoords($wayId);
			
			for( $x =0; $x < scalar (@wayNodes); $x++) {
				$nodeId = $wayNodes[$x];
                                $nodeLon = $aRef3->{$nodeId};
                                $nodeLat = $aRef4->{$nodeId};

				if ($nodeLon && $nodeLat) {   #some nodes can be out of region
                                	$lon{$nodeId} = $aRef3->{$nodeId};
                                	$lat{$nodeId} = $aRef4->{$nodeId};
					push @{$wayNodesHash{$wayId}}, $nodeId;
					if ($nodeLon > $maxLon) { $maxLon = $nodeLon ; }
					if ($nodeLon < $minLon) { $minLon = $nodeLon ; }
					if ($nodeLat > $maxLat) { $maxLat = $nodeLat ; }
					if ($nodeLat < $minLat) { $minLat = $nodeLat ; }
					}
				}
			}
		}
	}





print "number total ways: $wayCount\n" ;
print "number check ways: $checkWayCount\n" ;
print "number against ways: $againstWayCount\n" ;



$qt = OSM::QuadTree->new (	-xmin => $minLon, 
				-xmax => $maxLon, 
				-ymin => $minLat, 
				-ymax => $maxLat, 
				-depth => 8) ;


##########################
# init areas for chechWays
##########################
print "init areas for checkways...\n" ;
foreach $wayId (@checkWays) {

	($xMin{$wayId}, $xMax{$wayId}, $yMin{$wayId}, $yMax{$wayId}) = getArea ( @{$wayNodesHash{$wayId}} );

	$qt->add ($wayId, $xMin{$wayId}, $yMin{$wayId}, $xMax{$wayId}, $yMax{$wayId}) ;
}



###############################
# check for crossings
###############################
print "check for crossings...\n" ;

$progress = 0 ;
$timeA = time() ;

#push @againstWays, @checkWays ; #why?? Perche'??

my $total = scalar (@againstWays) ;

$potential = $total * scalar (@checkWays) ;

print "\nTotal ways to be checked = $total;  Potential crossing to be found = $potential\n";


foreach $wayId1 (@againstWays) {
	$progress++ ;
	if ( ($progress % 100) == 0 ) {
		print "--- $progress ways reached\n";	
		}

	# create temp array according to hash

	my ($aXMin, $aXMax, $aYMin, $aYMax) = getArea ( @{$wayNodesHash{$wayId1}} );
	my $ref = $qt->getEnclosedObjects ($aXMin, $aYMin, $aXMax, $aYMax) ;
	my @temp = @$ref ;

	foreach $wayId2 (@temp) {
		if ( $layer{$wayId1} ne $layer{$wayId2} ) {
			# don't do anything, ways on different layer
		}
		else { # ways on same layer
			# check for overlapping "way areas"

			if (checkOverlap ($aXMin, $aYMin, $aXMax, $aYMax, $xMin{$wayId2}, $yMin{$wayId2}, $xMax{$wayId2}, $yMax{$wayId2})) {
				$olc++ ;
				if ( ($wayCategory{$wayId1} == $wayCategory{$wayId2}) and ($wayId1 <= $wayId2) ) {
					# don't do anything because cat1/cat1 only if id1>id2
				}
				else {
					my $a ; my $b ;
					$checksDone++ ;
					for ($a=0; $a<$#{$wayNodesHash{$wayId1}}; $a++) {
						for ($b=0; $b<$#{$wayNodesHash{$wayId2}}; $b++) {
							my ($x, $y) = crossing ($lon{$wayNodesHash{$wayId1}[$a]}, 
									$lat{$wayNodesHash{$wayId1}[$a]}, 
									$lon{$wayNodesHash{$wayId1}[$a+1]}, 
									$lat{$wayNodesHash{$wayId1}[$a+1]}, 
									$lon{$wayNodesHash{$wayId2}[$b]}, 
									$lat{$wayNodesHash{$wayId2}[$b]}, 
									$lon{$wayNodesHash{$wayId2}[$b+1]}, 
									$lat{$wayNodesHash{$wayId2}[$b+1]}) ;
							if (($x != 0) and ($y != 0)) {
								$crossings++ ;
								@{$crossingsHash{$crossings}} = ($x, $y, $wayId1, $wayId2) ;
								#print "crossing: $x, $y, $wayId1, $wayId2\n" ;
							} # found
						} # for
					} # for
				} # categories
			} # overlap
		} 
	}
}

print "potential checks: $potential\n" ;
print "checks actually done: $checksDone\n" ;
my $percent = $checksDone / $potential * 100 ;
printf "work: %2.3f percent\n", $percent ;
print "crossings found: $crossings. some may be omitted because length of way under threshold.\n" ;
print "olc done: $olc\n" ;

$time1 = time () ;


##################
# PRINT HTML INFOS
##################
print "\nwrite HTML tables and GPX file, get bugs if specified...\n" ;

open ($html, ">", $htmlName) || die ("Can't open html output file") ;
open ($txt,  ">", $txtName) || die ("Can't open txt  output file") ;

printHTMLiFrameHeader ($html, "Crossings Check by Gary68") ;

print $html "<H1>Crossing Check by Gary68</H1>\n" ;
print $html "<p>Version ", $version, "</p>\n" ;
print $html "<p>Mode ", $mode, "</p>\n" ;
print $html "<H2>Statistics</H2>\n" ;
print $html "<p><br>\n" ;
print $html "number ways total: $wayCount<br>\n" ;
print $html "number check ways: $checkWayCount<br>\n" ;
print $html "number against ways: $againstWayCount</p>\n" ;

print $html "<p>Check ways: " ;
foreach (@check) { print $html $_, " " ;} print $html "</p>\n" ;
print $html "<p>Against: " ;
foreach (@against) { print $html $_, " " ;} print $html "</p>\n" ;


print $html "<H2>Crossings found where layer is the same</H2>\n" ;
print $html "<p>At the given location two ways intersect without a common node and on the same layer." ;
print $html "<table border=\"1\">\n";
print $html "<tr>\n" ;
print $html "<th>Line</th>\n" ;
print $html "<th>WayId1</th>\n" ;
print $html "<th>WayId2</th>\n" ;
print $html "<th>Links</th>\n" ;
print $html "<th>JOSM</th>\n" ;
print $html "</tr>\n" ;
$i = 0 ;




my @sorted = () ;
foreach $key (keys %crossingsHash) {
	my ($x, $y, $id1, $id2) = @{$crossingsHash{$key}} ;
	push @sorted, [$key, $x] ;
}

@sorted = sort { $a->[1] <=> $b->[1]} @sorted ;

foreach my $s (@sorted) {

	my $key ;	
	$key = $s->[0] ;

	my ($x, $y, $id1, $id2) = @{$crossingsHash{$key}} ;

	# TXT
	print $txt "XING_"."$x"."_"."$y\n";

	$i++ ;
	# HTML
	print $html "<tr>\n" ;
	print $html "<td>", $i , "</td>\n" ;
	print $html "<td>", historyLink ("way", $id1) , "</td>\n" ;
	print $html "<td>", historyLink ("way", $id2) , "</td>\n" ;
	print $html "<td>", osmLink ($x, $y, 16) , "</td>\n" ;
	#Sabas improved
#	print $html "<td>", josmLinkSelectWays ($x, $y, 0.01, $id1, $id2), "</td>\n" ;
	print $html "<td>", josmLinkSelectWays ($x, $y, 0.0001, $id1, $id2), "</td>\n" ;
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
close ($txt) ;


print "\n$program finished after ", stringTimeSpent ($time1-$time0), "\n\n" ;



###### -------------------------------- functions -------------------------


sub getArea {
	my @nodes = @_ ;

	my $minLon = 999 ;
	my $maxLon = -999 ;
	my $minLat = 999 ;
	my $maxLat = -999 ;


	foreach my $node (@nodes) {
		if ($lon{$node} > $maxLon) { $maxLon = $lon{$node} ; }
		if ($lon{$node} < $minLon) { $minLon = $lon{$node} ; }
		if ($lat{$node} > $maxLat) { $maxLat = $lat{$node} ; }
		if ($lat{$node} < $minLat) { $minLat = $lat{$node} ; }
	}	
	return ($minLon, $maxLon, $minLat, $maxLat) ;
}


