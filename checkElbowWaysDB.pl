#
# Vie a gomito:  check with data in a SQLite db
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

use Time::localtime;
use Array::Utils qw(:all);

my @tags = qw (highway:trunk highway:primary highway:secondary highway:tertiary highway:residential highway:unclassified 
               highway:trunk_link highway:primary_link highway:secondary_link  
         highway:track highway:steps highway:pedestrian highway:footway );



my $MAX_DELTA_ANGLE = 135;  #angolo massimo tra due spezzoni di way


my $program = "checkElbowWaysDB.pl" ;
my $version = "1.0" ;
my $usage = $program . " <database>.sqlite <html_output.html> <tasks_output.txt>" ;

my $wayId ;
my @wayNodes ;
my @wayTags ;
my $nodeId ;
my $aRef1 ;
my $aRef2 ;
my $aRef3 ;
my $aRef4 ;

my $time0 = time() ; my $time1 ;
my $i ;
my $tag1 ; 

my $html ;
my $htmlName ;
my $dbName ;
my $txt ;
my $txtName ;


my @highways ;
my %lon ;
my %lat ;
my %highwayNodes ;


###############
# get parameter
###############


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

print "\nINFO: write HTML tables...\n" ;


open ($html, ">", $htmlName) || die ("Can't open html output file") ;

printHTMLHeader ($html, "$program" ) ;

print $html "<H1>$program </H1>\n" ;


print $html "<H2>Vie a Gomito</H2>\n" ;
print $html "<p>Queste vie presentano tratti con curve troppo accentuate</p>" ;
print $html "<table border=\"1\" width=\"100%\">\n";
print $html "<tr>\n" ;
print $html "<th>Line</th>\n" ;
print $html "<th>WayId</th>\n" ;
print $html "<th>Type</th>\n" ;
print $html "<th>Node</th>\n" ;
print $html "<th>OSM</th>\n" ;
print $html "<th>JOSM</th>\n" ;
print $html "</tr>\n" ;
$i = 0 ;

######################
# identify ways
######################
print "INFO: pass1: find ways...\n" ;


my $null;

foreach (@tags) {
        my @tmp = split(/:/, $_);

        print "Cerco vie con tag @tmp e angolo tra i segmenti maggiore di $MAX_DELTA_ANGLE\n";

        loopInitWays($tmp[0], $tmp[1]);

	while ($wayId = loopGetNextWay ) {
	
	
		($null, $aRef1, $aRef2) = getDBWay($wayId);
		@wayNodes = @$aRef1 ; #nodes are ordered 0,1,2, etc
		@wayTags = @$aRef2 ;


#	print "way $wayId - nodi= " . scalar @wayNodes ."  primo $wayNodes[0]    ultimo $wayNodes[-1] reverse=$reverse\n";


		my $maxWayNodes = scalar @wayNodes;

		if ( $maxWayNodes > 2 && ($wayNodes[0] != $wayNodes[-1])) {
			#evito le way chiuse


			($aRef3, $aRef4) = getDBWayNodesCoords($wayId);
			my $x = 0;

			for ($x=0; $x<$maxWayNodes; $x++) {
				$nodeId = $wayNodes[$x];
				$lon{$nodeId} = $aRef3->{$nodeId};
				$lat{$nodeId} = $aRef4->{$nodeId};	
					
				$highwayNodes{$wayId}[$x] = $nodeId;
				}
	
			#faccio il controllo per vedere se e' una way a gomito
			for ($x=0; $x<$maxWayNodes-3; $x++) {
				my $node0 =  $highwayNodes{$wayId}[$x] ;	
				my $node1 =  $highwayNodes{$wayId}[$x+1] ;	
				my $node2 =  $highwayNodes{$wayId}[$x+2] ;	
	
	
				#se ho tutte le info sui nodi
				if ( $lon{$node0} && $lon{$node1} && $lon{$node2} ) {
	
					# angle (x1,y1,x2,y2)					> angle (N=0,E=90...)
					my $angle1 = angle ($lon{$node0}, $lat{$node0}, $lon{$node1}, $lat{$node1}) ; 
					my $angle2 = angle ($lon{$node1}, $lat{$node1}, $lon{$node2}, $lat{$node2}) ; 

					#if ( $angle1 <  $angle2 ) {  $angle1 += 360; }

					my $angleDelta = $angle2 - $angle1 ;
					if ($angleDelta > 180) { $angleDelta = $angleDelta - 360 ; }
					if ($angleDelta < -180) { $angleDelta = $angleDelta + 360 ; }
				
					if ( abs  $angleDelta > $MAX_DELTA_ANGLE ) {
#						print " way $wayId (#nodi = $maxWayNodes) al nodo $node1  angoli ", int  $angle1," ", int  $angle2, " delta= ", int abs $angleDelta ,"\n";

						$i++ ;

						print $html "<tr>\n" ;
						print $html "<td>", $i , "</td>\n" ;

						print $html "<td>", historyLink ("way", $wayId) , "</td>\n" ;
						print $html "<td>", $tmp[0], "=", $tmp[1] , "</td>\n" ;
						print $html "<td>", historyLink ("node", $node1) , "</td>\n" ;
						print $html "<td>", osmLink ($lon{$node1}, $lat{$node1}, 16) , "</td>\n" ;
						print $html "<td>", josmLinkSelectNode ($lon{$node1}, $lat{$node1}, 0.0005, $node1), "</td>\n" ;
						print $html "</tr>\n" ;
						}
					}
				}
		       }
		}	
	}



		

$time1 = time () ;



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

#open ($txt, ">", $txtName) || die ("Can't open txt output file") ;
#print "\n----- ROUNDABOUTS ----------\n";
#foreach $wayId (@wrong_round) {
#	print $txt "ROU_$wayId\n";
#	}
#print "\n----- TOO SMALL ROUNDABOUTS ----------\n";
#foreach $wayId (@small_roundabouts) {
#	print $txt "ROU_$wayId\n";
#	}


#close ($txt) ;



#statistics ( ctime(stat($osmName)->mtime),  $program,  "roundabout", $osmName,  $roundaboutCount,  $i) ;

print "\nINFO: finished after ", stringTimeSpent ($time1-$time0), "\n\n" ;



