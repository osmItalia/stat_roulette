#
# Roundabout check with data in a SQLite db
# by sbiribizio
# Based on roundabout check by gary68
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
# 1.0
#



use strict ;
use warnings ;

use OSM::osm ;
use OSM::osmDB_SQLite ;
#use File::stat;
use Time::localtime;



my $program = "checkRoundaboutDB.pl" ;
my $version = "1.0" ;
my $usage = $program . " <direction> <database>.sqlite <html_output.html> <tasks_output.txt> // direction = [L|R] ( L  for italian roads)" ;

my $wayId ;
my @wayNodes ;
my @wayTags ;
my $nodeId ;
my $aRef1 ;
my $aRef2 ;
my $aRef3 ;
my $aRef4 ;
my $roundaboutCount = 0 ;
my $small_roundaboutCount = 0 ;
my $onewayWrongCount = 0 ;

my $time0 = time() ; my $time1 ;
my $i ;
my $tag1 ; 
my $direction = "" ;

my $html ;
my $htmlName ;
my $dbName ;
my $txt ;
my $txtName ;


my @roundabouts ;
my @small_roundabouts ;
my @wrong_round ;
my %lon ;
my %lat ;
my %wayStart ;
my %wayEnd ;
my %roundaboutTags ;
my %roundaboutNodes ;


###############
# get parameter
###############

$direction = shift||'';
if (!$direction)
{
        die (print "\nUSAGE: $usage", "\n\n");
}

$dbName =  shift||'';
if (!$dbName)
{
        die (print "\nUSAGE: $usage", "\n\n");
}

$htmlName =  shift||'';
if (!$htmlName)
{
        die (print "\nUSAGE: $usage", "\n\n");
}

$txtName =  shift||'';
if (!$txtName)
{
        die (print "\nUSAGE: $usage", "\n\n");
}

print "\n\n" ;





######################
# open DB
######################
my @parametri = ($dbName, '', '');
dbConnect @parametri;


######################
# identify roundabouts
######################
print "INFO: pass1: find roundabouts...\n" ;


my $null;

loopInitWays('junction','roundabout');
while ($wayId = loopGetNextWay ) {
	
	my $reverse = 0; # flag for tag oneway = -1
	
	($null, $aRef1, $aRef2) = getDBWay($wayId);
	@wayNodes = @$aRef1 ; #nodes are ordered 0,1,2, etc
	@wayTags = @$aRef2 ;


	foreach $tag1 (@wayTags) {
		# searching for tag oneway = -1
		if ( $tag1->[0] eq "oneway" and $tag1->[1] eq "-1") {$reverse = 1;}
		}


#	print "way $wayId - nodi= " . scalar @wayNodes ."  primo $wayNodes[0]    ultimo $wayNodes[-1] reverse=$reverse\n";

	if ((scalar @wayNodes > 2 ) and  $wayNodes[0]==$wayNodes[-1]) {
		# check if the way is closed (first and last node must be the same)
		# and the nodes are > 2
               $roundaboutCount++ ;
               push @roundabouts, $wayId ;
               $wayStart{$wayId} = $wayNodes[0] ;
               $wayEnd{$wayId} = $wayNodes[-1] ;
               @{$roundaboutTags{$wayId}} = @wayTags ;

		($aRef3, $aRef4) = getDBWayNodesCoords($wayId);

		# for the next check of the angle I need only the first 3 nodes of the way
		# if the way is reversed, take the nodes from the end of the array
		my $x = 0;

                if ($reverse) { 
			for ($x=-1; $x>-4; $x--) {
				$nodeId = $wayNodes[$x];
				$lon{$nodeId} = $aRef3->{$nodeId};
				$lat{$nodeId} = $aRef4->{$nodeId};	
				
				my $index = abs($x) -1;
				$roundaboutNodes{$wayId}[$index] = $nodeId;
				}
			$wayStart{$wayId} = $wayNodes[-1];
               		$wayEnd{$wayId} = $wayNodes[0] ;
			}
		else {
			for ($x=0; $x<3; $x++) {
				$nodeId = $wayNodes[$x];
				$lon{$nodeId} = $aRef3->{$nodeId};
				$lat{$nodeId} = $aRef4->{$nodeId};	
				
				$roundaboutNodes{$wayId}[$x] = $nodeId;
				}	
			}
	       }

	if ((scalar @wayNodes <= 4 ) and  $wayNodes[0]==$wayNodes[-1]) {
		#we have a closed way, tagged roundabout
		#but with only 3 nodes
		# 
               $small_roundaboutCount++ ;
		push @small_roundabouts, $wayId ;
               $wayStart{$wayId} = $wayNodes[0] ;
               $wayEnd{$wayId} = $wayNodes[-1] ;
               @{$roundaboutTags{$wayId}} = @wayTags ;
		}
	}


# next check: ways tagged as mini_roundabout

#loopInitWays('junction','roundabout');
#while ($wayId = loopGetNextWay ) {
#}



print "INFO: number roundabouts: $roundaboutCount\n" ;
print "INFO: number small roundabouts: $small_roundaboutCount\n" ;




######################
# computation 
######################
print "INFO: pass2: computation....\n" ;


foreach $wayId (@roundabouts) {

		# angle (x1,y1,x2,y2)					> angle (N=0,E=90...)
		my $node0 = @{$roundaboutNodes{$wayId}}[0] ;
		my $node1 = @{$roundaboutNodes{$wayId}}[1] ; 
		my $node2 = @{$roundaboutNodes{$wayId}}[2] ; 
		
		my $angle1 = angle ($lon{$node0}, $lat{$node0}, $lon{$node1}, $lat{$node1}) ; 
		my $angle2 = angle ($lon{$node1}, $lat{$node1}, $lon{$node2}, $lat{$node2}) ; 
		my $angleDelta = $angle2 - $angle1 ;
# print "$wayId $angle1 $angle2 $angleDelta\n" ;
		if ($angleDelta > 180) { $angleDelta = $angleDelta - 360 ; }
		if ($angleDelta < -180) { $angleDelta = $angleDelta + 360 ; }
		if ( 	( ($direction eq "L") and ($angleDelta > 0) ) or
			( ($direction eq "R") and ($angleDelta < 0)) ) {
			$onewayWrongCount ++ ;
			push @wrong_round, $wayId ;
		}
}
print "INFO: number wrong roundabouts: $onewayWrongCount\n" ;

$time1 = time () ;


######################
# PRINT HTML INFOS
######################
print "\nINFO: write HTML tables...\n" ;


open ($html, ">", $htmlName) || die ("Can't open html output file") ;

printHTMLHeader ($html, "$program by sbiribizio") ;

print $html "<H1>$program by sbiribizio</H1>\n" ;
print $html "<p>Version ", $version, "</p>\n" ;

print $html "<H2>Statistics</H2>\n" ;
#print $html "<p>", stringFileInfo ($osmName), "<br>\n" ;
#print $html "number ways total: $wayCount<br>\n" ;
print $html "number roundabouts: $roundaboutCount</p>\n" ;
print $html "number wrong roundabouts: $onewayWrongCount</p>\n" ;


print $html "<H2>Wrong roundabouts</H2>\n" ;
print $html "<p>These roundabouts have the wrong direction <b>or</b> aren't perfectly circular.</p>" ;
print $html "<table border=\"1\" width=\"100%\">\n";
print $html "<tr>\n" ;
print $html "<th>Line</th>\n" ;
print $html "<th>WayId</th>\n" ;
print $html "<th>Tags</th>\n" ;
print $html "<th>Nodes</th>\n" ;
print $html "<th>OSM start</th>\n" ;
print $html "<th>JOSM start</th>\n" ;
print $html "</tr>\n" ;
$i = 0 ;
foreach $wayId (@wrong_round) {
	$i++ ;

	print $html "<tr>\n" ;
	print $html "<td>", $i , "</td>\n" ;
	print $html "<td>", historyLink ("way", $wayId) , "</td>\n" ;

	print $html "<td>" ;
	foreach (@{$roundaboutTags{$wayId}}) { 
		print $html @$_[0],'=', @$_[1], " - " ; 
		}
	print $html "</td>\n" ;

	print $html "<td>" ;
	foreach (@{$roundaboutNodes{$wayId}}) { print $html $_, " - " ; }
	print $html "</td>\n" ;

	print $html "<td>", osmLink ($lon{$wayStart{$wayId}}, $lat{$wayStart{$wayId}}, 16) , "</td>\n" ;
	print $html "<td>", josmLink ($lon{$wayStart{$wayId}}, $lat{$wayStart{$wayId}}, 0.005, $wayId), "</td>\n" ;

	print $html "</tr>\n" ;

}

print $html "</table>\n" ;
print $html "<p>$i lines total</p>\n" ;

#  SMALL ROUNDABOUTS

print $html "<p>These roundabouts are too small.</p>" ;
print $html "<table border=\"1\" width=\"100%\">\n";
print $html "<tr>\n" ;
print $html "<th>Line</th>\n" ;
print $html "<th>WayId</th>\n" ;
print $html "<th>Tags</th>\n" ;
print $html "<th>Nodes</th>\n" ;
print $html "<th>OSM start</th>\n" ;
print $html "<th>JOSM start</th>\n" ;
print $html "</tr>\n" ;
$i = 0 ;
foreach $wayId (@small_roundabouts) {
        $i++ ;

        print $html "<tr>\n" ;
        print $html "<td>", $i , "</td>\n" ;
        print $html "<td>", historyLink ("way", $wayId) , "</td>\n" ;

        print $html "<td>" ;
        foreach (@{$roundaboutTags{$wayId}}) {
                print $html @$_[0],'=', @$_[1], " - " ;
                }
        print $html "</td>\n" ;

        print $html "<td>" ;
        foreach (@{$roundaboutNodes{$wayId}}) { print $html $_, " - " ; }
        print $html "</td>\n" ;

        print $html "<td>", osmLink ($lon{$wayStart{$wayId}}, $lat{$wayStart{$wayId}}, 16) , "</td>\n" ;
        print $html "<td>", josmLink ($lon{$wayStart{$wayId}}, $lat{$wayStart{$wayId}}, 0.005, $wayId), "</td>\n" ;

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
print "\n----- ROUNDABOUTS ----------\n";
foreach $wayId (@wrong_round) {
	print $txt "ROU_$wayId\n";
	}
print "\n----- TOO SMALL ROUNDABOUTS ----------\n";
foreach $wayId (@small_roundabouts) {
	print $txt "ROU_$wayId\n";
	}


close ($txt) ;



#statistics ( ctime(stat($osmName)->mtime),  $program,  "roundabout", $osmName,  $roundaboutCount,  $i) ;

print "\nINFO: finished after ", stringTimeSpent ($time1-$time0), "\n\n" ;



