# 
# PERL mapgen module by gary68
#
# This module contains a lot of useful graphic functions for working with osm files and data. This enables you (in conjunction with osm.pm)
# to easily draw custom maps.
# Have a look at the last (commented) function below. It is useful for your main program!
#
#
#
#
# Copyright (C) 2010, Gerhard Schwanz
#
# This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the 
# Free Software Foundation; either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program; if not, see <http://www.gnu.org/licenses/>

#
# INFO
#
# graph top left coordinates: (0,0)
# size for lines = pixel width / thickness
#
# 1.051 l0 calculation adapted


package OSM::mapgen ; #  

use strict ;
use warnings ;

use Math::Trig;
use File::stat;
use Time::localtime;
use List::Util qw[min max] ;
use Encode ;
use OSM::osm ;
use OSM::QuadTree ;
use GD ;
use Geo::Proj4 ;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

$VERSION = '1.19' ;

require Exporter ;

@ISA = qw ( Exporter AutoLoader ) ;

@EXPORT = qw ( 		addAreaIcon
			addOnewayArrows
			center
			convert
			createLabel
			createWayLabels
			declutterStat
			drawArea 
			drawAreaMP
			drawAreaOcean
			drawAreaPix 
			drawCircle 
			drawCircleRadius 
			drawCircleRadiusText 
			drawCoords
			drawHead 
			drawFoot 
			drawGrid
			drawLegend 
			drawNodeDot 
			drawNodeDotRouteStops 
			drawNodeDotPix 
			drawNodeCircle 
			drawNodeCirclePix 
			drawPageNumber
			drawPageNumberTop
			drawPageNumberBottom
			drawPageNumberLeft
			drawPageNumberRight
			drawRuler 
			drawTextPix 
			drawTextPix2 
			drawTextPixGrid
			drawWay 
			drawWayBridge 
			drawWayPix 
			drawWayRoute
			fitsPaper
			getDimensions
			getScale
			getValue
			gridSquare
			initGraph 
			initOneways
			labelWay 
			placeLabelAndIcon
			printScale
			scalePoints
			scaleBase
			setdpi 
			setBaseDpi
			simplifiedPercent
			sizePNG 
			sizeSVG
			writeSVG ) ;

#
# constants
#

my %dashStyle = () ;
my %dashDefinition = () ; # for 300 dpi
@{$dashDefinition{1}} = (60,20,"round") ; #grid
@{$dashDefinition{11}} = (16,16,"butt") ; # tunnel

my $wayIndexLabelColor = 9 ;
my $wayIndexLabelSize = 10 ;
my $wayIndexLabelFont = 11 ;
my $wayIndexLabelOffset = 12 ;
my $wayIndexLegendLabel = 14 ;

my $lineCap = "round" ;
my $lineJoin = "round" ;

my @occupiedAreas = () ;
my $labelPathId = 0 ;

my $qtWayLabels ;
my $qtPoiLabels ;

#
# variables
#
my $proj ;
my $projSizeX ;
my $projSizeY ;
my ($projLeft, $projRight, $projBottom, $projTop) ;


my ($top, $bottom, $left, $right) ; # min and max real world coordinates
my ($sizeX, $sizeY) ; # pic size in pixels

my %svgOutputWays ;
my %svgOutputNodes ;
my @svgOutputAreas = () ;
my @svgOutputText = () ;
my @svgOutputPixel = () ;
my @svgOutputPixelGrid = () ;
my @svgOutputDef = () ;
my @svgOutputPathText = () ;
my @svgOutputIcons = () ;
my @svgOutputRouteStops = () ;
my $pathNumber = 0 ;
my $svgBaseFontSize = 10 ;
my @svgOutputRoutes = () ;

my %areaDef = () ;
my $areaNum = 1 ;

my $numIcons = 0 ;
my $numIconsMoved = 0 ;
my $numIconsOmitted = 0 ;
my $numLabels = 0 ;
my $numLabelsMoved = 0 ;
my $numLabelsOmitted = 0 ;
my $numWayLabelsOmitted = 0 ;

my $dpi = 0 ;
my $baseDpi ;

# clutter information
my %clutter = () ;
my %clutterIcon = () ;
my @lines ;

my $simplified = 0 ;
my $simplifyTotal = 0 ;

my $shieldPathId = 0 ;
my %createdShields = () ; # key = name; value = id of path
my %shieldXSize = () ;
my %shieldYSize = () ;


sub setdpi {
	$dpi = shift ;
}

sub setBaseDpi {
	$baseDpi = shift ;
}


sub initGraph {
#
# function initializes the picture, the colors and the background (white)
#
	my ($x, $l, $b, $r, $t, $color, $projection, $ellipsoid) = @_ ;	

	# my $l0 = int($l) - 1 ;
	my $l0 = int(($r+$l) / 2 ) ;

	$proj = Geo::Proj4->new(
		proj => $projection, 
		ellps => $ellipsoid, 
		lon_0 => $l0 
		) or die "parameter error: ".Geo::Proj4->error. "\n"; 


	($projLeft, $projBottom) = $proj->forward($b, $l) ; # lat/lon!!!
	($projRight, $projTop) = $proj->forward($t, $r) ; # lat/lon!!!

	# print "PROJ: bounds: $projLeft $projRight $projBottom $projTop\n" ;

	$projSizeX = $projRight - $projLeft ;
	$projSizeY = $projTop - $projBottom ;

	my $factor = $projSizeY / $projSizeX ;

	# print "PROJ: $projSizeX x $projSizeY units, factor = $factor\n" ;
	
	$sizeX = int ($x) ;
	$sizeY = int ($x * $factor) ;

	# print "PROJ: $sizeX x $sizeY pixels\n" ;
	# print "PROJ: t b l r $t $b $l $r\n" ;
	# print "PROJ: pt pb pl pr $projTop $projBottom $projLeft $projRight\n" ;
	# print "PROJ: factor $factor\n" ;
	# print "PROJ: l0 $l0\n" ;

	$top = $t ;
	$left = $l ;
	$right = $r ;
	$bottom = $b ;

	drawArea ($color, "", $l, $t, $r, $t, $r, $b, $l, $b, $l, $t) ;

	$qtWayLabels = OSM::QuadTree->new(  -xmin  => 0,
                                      -xmax  => $sizeX+100,
                                      -ymin  => 0,
                                      -ymax  => $sizeY+40,
                                      -depth => 5);
	$qtPoiLabels = OSM::QuadTree->new(  -xmin  => 0,
                                      -xmax  => $sizeX+100,
                                      -ymin  => 0,
                                      -ymax  => $sizeY+40,
                                      -depth => 5);
	initDashes() ;
}

sub initDashes {
#
# sub creates internal dash styles according to base definition
#
	foreach my $style (keys %dashDefinition) {
		my @array = @{$dashDefinition{$style}} ;
		my $lc = pop @array ;
		my $dashString = "" ;
		foreach my $entry (@array) {
			my $entryScaled = scalePoints ( scaleBase ($entry) ) ;
			$dashString .= "$entryScaled," ;
		}
		$dashString .= $lc ;
		$dashStyle{$style} = $dashString ;
	}
}



sub convert {
#
# converts real world coordinates to system graph pixel coordinates
#
	my ($x, $y) = @_ ;

	my ($x1, $y1) = $proj->forward($y, $x) ; # lat/lon!!!

	my $x2 = int ( ($x1 - $projLeft) / ($projRight - $projLeft) * $sizeX ) ;
	my $y2 = $sizeY - int ( ($y1 - $projBottom) / ($projTop - $projBottom) * $sizeY ) ;

	return ($x2, $y2) ;
}

sub gridSquare {
#
# returns grid square of given coordinates for directories
#
	my ($lon, $lat, $parts) = @_ ;
	my ($x, $y) = convert ($lon, $lat) ;
	# my $partsY = $sizeY / ($sizeX / $parts) ;
	my $xi = int ($x / ($sizeX / $parts)) + 1 ;
	my $yi = int ($y / ($sizeX / $parts)) + 1 ;
	if ( ($x >= 0) and ($x <= $sizeX) and ($y >= 0) and ($y <= $sizeY) ) {
		return (chr($xi+64) . $yi) ;
	}
	else {
		return undef ;
	}
}



sub occupyArea {
#
# occupy area and make entry in quad tree for later use
#
	my ($x1, $x2, $y1, $y2) = @_ ;
	# left, right, bottom, top (bottom > top!)
	push @occupiedAreas, [$x1, $x2, $y1, $y2] ;
	$qtPoiLabels->add ($#occupiedAreas, $x1, $y1, $x2, $y2) ;
}

sub areaOccupied {
#
# look up possible interfering objects in quad tree and check for collision
#
	my ($x1, $x2, $y1, $y2) = @_ ;
	# left, right, bottom, top (bottom > top!)
	my $occupied = 0 ;

	my $ref2 = $qtPoiLabels->getEnclosedObjects ($x1, $y2, $x2, $y1) ;
	my @index = @$ref2 ;
	my @occupiedAreasTemp = () ;
	foreach my $nr (@index) {
		push @occupiedAreasTemp, $occupiedAreas[$nr] ;
	} 

	LAB1: foreach my $area (@occupiedAreasTemp) {
		my $intersection = 1 ;
		if ($x1 > $area->[1]) { $intersection = 0 ; } ;
		if ($x2 < $area->[0]) { $intersection = 0 ; } ;
		if ($y1 < $area->[3]) { $intersection = 0 ; } ;
		if ($y2 > $area->[2]) { $intersection = 0 ; } ;
		if ($intersection == 1) { 
			$occupied = 1 ; 
			last LAB1 ;	
		}
	}
	return ($occupied) ;
}

sub splitLabel {
#
# split label text at space locations and then merge new parts if new part will be smaller than 21 chars
#
	my $text = shift ;
	my @lines = split / /, $text ;
	my $merged = 1 ;
	while ($merged) {
		$merged = 0 ;
		LAB2: for (my $i=0; $i<$#lines; $i++) {
			if (length ($lines[$i] . " " . $lines[$i+1]) <= 20) {
				$lines[$i] = $lines[$i] . " " . $lines[$i+1] ;
				splice (@lines, $i+1, 1) ;
				$merged = 1 ;
				last LAB2 ;
			}
		}
	}
	return (\@lines) ;
}


sub svgElementIcon {
#
# create SVG text for icons
#
	my ($x, $y, $icon, $sizeX, $sizeY) = @_ ;
	my ($out) = "<image x=\"" . $x . "\"" ;
	$out .= " y=\"" . $y . "\"" ;
	if ($sizeX > 0) { $out .= " width=\"" . $sizeX . "\"" ; }
	if ($sizeY > 0) { $out .= " height=\"" . $sizeY . "\"" ; }
	$out .= " xlink:href=\"" . $icon . "\" />" ;

	return ($out) ;	
}

sub drawHead {
#
# draws text on top left corner of the picture
#
	my ($text, $col, $size, $font) = @_ ;
	push @svgOutputText, svgElementText (20, 20, $text, $size, $font, $col) ;
}

sub drawFoot {
#
# draws text on bottom left corner of the picture
#
	my ($text, $col, $size, $font) = @_ ;
	my $posX = 80 ;
	my $posY = 40 ;
	push @svgOutputText, svgElementText (
		scalePoints ( scaleBase ($posX) ), 
		$sizeY - ( scalePoints ( scaleBase ($posY) ) ), 
		$text, 
		scalePoints ( scaleBase ($size) ) , 
		$font, 
		$col
	) ;
}



sub drawTextPix {
#
# draws text at pixel position
# with small offset direction bottom
#
	my ($x1, $y1, $text, $col, $size, $font) = @_ ;

	push @svgOutputPixel, svgElementText ($x1, $y1, $text, $size, $font, $col) ;
}

sub drawTextPixGrid {
#
# draws text at pixel position. code goes to grid
#
	my ($x1, $y1, $text, $col, $size) = @_ ;

	push @svgOutputPixelGrid, svgElementText ($x1, $y1+9, $text, $size, "sans-serif", $col) ;
}

sub drawNodeDot {
#
# draws node as a dot at given real world coordinates
#
	my ($lon, $lat, $col, $size) = @_ ;
	my ($x1, $y1) = convert ($lon, $lat) ;
	push @{$svgOutputNodes{0}}, svgElementCircleFilled ($x1, $y1, $size, $col) ;
}

sub drawNodeDotRouteStops {
#
# draws node as a dot at given real world coordinates
#
	my ($lon, $lat, $col, $size) = @_ ;
	my ($x1, $y1) = convert ($lon, $lat) ;
	push @svgOutputRouteStops, svgElementCircleFilled ($x1, $y1, $size, $col) ;
}

sub drawNodeDotPix {
#
# draws node as a dot at given pixels
#
	my ($x1, $y1, $col, $size) = @_ ;
	push @svgOutputPixel, svgElementCircleFilled ($x1, $y1, $size, $col) ;
}


sub drawCircle {
	my ($lon, $lat, $radius, $color, $thickness) = @_ ;
	# radius in meters

	my ($x, $y) = convert ($lon, $lat) ;
	my $thickness2 = scalePoints ($thickness) ;

	my $radiusPixel = $radius / (1000 * distance ($left, $bottom, $right, $bottom) ) * $sizeX ;
	push @svgOutputPixelGrid, svgElementCircle ($x, $y, $radiusPixel, $thickness2, $color) ;
}

sub drawWay {
#
# draws way as a line at given real world coordinates. nodes have to be passed as array ($lon, $lat, $lon, $lat...)
# $size = thickness
#
	my ($layer, $col, $size, $dash, @nodes) = @_ ;
	my $i ;
	my @points = () ;

	for ($i=0; $i<$#nodes; $i+=2) {
		my ($x, $y) = convert ($nodes[$i], $nodes[$i+1]) ;
		push @points, $x ; push @points, $y ; 
	}
	push @{$svgOutputWays{$layer+$size/100}}, svgElementPolyline ($col, $size, $dash, @points) ;
}

sub drawWayBridge {
#
# draws way as a line at given real world coordinates. nodes have to be passed as array ($lon, $lat, $lon, $lat...)
# $size = thickness
#
	my ($layer, $col, $size, $dash, @nodes) = @_ ;
	my $i ;
	my @points = () ;

	if ($dash eq "11") { $dash = $dashStyle{11} ; }

	for ($i=0; $i<$#nodes; $i+=2) {
		my ($x, $y) = convert ($nodes[$i], $nodes[$i+1]) ;
		push @points, $x ; push @points, $y ; 
	}
	push @{$svgOutputWays{$layer+$size/100}}, svgElementPolylineBridge ($col, $size, $dash, @points) ;
}

sub drawWayPix {
#
# draws way as a line at given pixels. nodes have to be passed as array ($x, $y, $x, $y...)
# $size = thickness
#
	my ($col, $size, $dash, @nodes) = @_ ;
	my $i ;
	my @points = () ;

	for ($i=0; $i<$#nodes; $i+=2) {
		my ($x, $y) = ($nodes[$i], $nodes[$i+1]) ;
		push @points, $x ; push @points, $y ; 
	}
	push @svgOutputPixel, svgElementPolyline ($col, $size, $dash, @points) ;
}

sub drawWayPixGrid {
#
# draws way as a line at given pixels. nodes have to be passed as array ($x, $y, $x, $y...)
# $size = thickness
#
	my ($col, $size, $dash, @nodes) = @_ ;
	my $i ;
	my @points = () ;

	for ($i=0; $i<$#nodes; $i+=2) {
		my ($x, $y) = ($nodes[$i], $nodes[$i+1]) ;
		push @points, $x ; push @points, $y ; 
	}
	push @svgOutputPixelGrid, svgElementPolyline ($col, $size, $dash, @points) ;
}


sub labelWay {
#
# labels a way
#
	my ($col, $size, $font, $text, $tSpan, @nodes) = @_ ;
	my $i ;
	my @points = () ;

	for ($i=0; $i<$#nodes; $i+=2) {
		my ($x, $y) = convert ($nodes[$i], $nodes[$i+1]) ;
		push @points, $x ; push @points, $y ; 
	}
	my $pathName = "Path" . $pathNumber ; $pathNumber++ ;
	push @svgOutputDef, svgElementPath ($pathName, @points) ;
	push @svgOutputPathText, svgElementPathTextAdvanced ($col, $size, $font, $text, $pathName, $tSpan, "middle", 50, 0) ;
}


sub createWayLabels {
#
# finally take all way label candidates and try to label them
#
	my ($ref, $ruleRef, $declutter, $halo, $svgName) = @_ ;
	my @labelCandidates = @$ref ;
	my @wayRules = @$ruleRef ;
	my %notDrawnLabels = () ;
	my %drawnLabels = () ;

	# calc ratio to label ways first where label just fits
	# these will be drawn first
	foreach my $candidate (@labelCandidates) {
		my $wLen = $candidate->[2] ;
		my $lLen = $candidate->[3] ;
		if ($wLen == 0) { $wLen = 1 ; }
		if ($lLen == 0) { $lLen = 1 ; }
		$candidate->[5] = $lLen / $wLen ;
	}
	@labelCandidates = sort { $b->[5] <=> $a->[5] } @labelCandidates ;

	foreach my $candidate (@labelCandidates) {
		my $rule = $candidate->[0] ; # integer
		my @ruleData = @{$wayRules[$rule]} ;
		my $name = $candidate->[1] ;
		my $wLen = $candidate->[2] ;
		my $lLen = $candidate->[3] ;
		my @points = @{$candidate->[4]} ;

		my $toLabel = 1 ;
		if ( ($declutter eq "1") and ($points[0] > $points[-2]) and ( ($ruleData[1] eq "motorway") or ($ruleData[1] eq "trunk") ) ) {
			$toLabel = 0 ;
		}

		if ($lLen > $wLen*0.95) {
			$notDrawnLabels { $name } = 1 ;
		}

		if ( ($lLen > $wLen*0.95) or ($toLabel == 0) ) {
			# label too long
			$numWayLabelsOmitted++ ;
		}
		else {

			if (grep /shield/i, $name) {
				# create shield if necessary
				if ( ! defined $createdShields{ $name }) {
					createShield ($name, $ruleData[$wayIndexLabelSize]) ;
				}

				# @points = (x1, y1, x2, y2 ... ) 
				# $wLen in pixels
				# $lLen in pixels
				# <use xlink:href="#a661" x="40" y="40" />

				my $shieldMaxSize = $shieldXSize{ $name } ;
				if ($shieldYSize{ $name } > $shieldMaxSize) { $shieldMaxSize = $shieldYSize{ $name } ; } 

				my $numShields = int ($wLen / ($shieldMaxSize * 12) ) ;
				# if ($numShields > 4) { $numShields = 4 ; } 

				if ($numShields > 0) {
					my $step = $wLen / ($numShields + 1) ;
					my $position = $step ; 
					while ($position < $wLen) {
						my ($x, $y) = getPointOfWay (\@points, $position) ;
						# print "XY: $x, $y\n" ;

						# place shield if not occupied
			
						my $x2 = int ($x - $shieldXSize{ $name } / 2) ;
						my $y2 = int ($y - $shieldYSize{ $name } / 2) ;

						# print "AREA: $x2, $y2, $x2+$lLen, $y2+$lLen\n" ;

						if ( ! areaOccupied ($x2, $x2+$shieldXSize{ $name }, $y2+$shieldYSize{ $name }, $y2) ) {

							my $id = $createdShields{$name};
							push @svgOutputIcons, "<use xlink:href=\"#$id\" x=\"$x2\" y=\"$y2\" />" ;

							occupyArea ($x2, $x2+$shieldXSize{ $name }, $y2+$shieldYSize{ $name }, $y2) ;
						}

						$position += $step ;
					}
				}

			}

			else {

				# print "$wLen - $name - $lLen\n" ;
				my $numLabels = int ($wLen / (4 * $lLen)) ;
				if ($numLabels < 1) { $numLabels = 1 ; }
				if ($numLabels > 4) { $numLabels = 4 ; }

				if ($numLabels == 1) {
					my $spare = 0.95 * $wLen - $lLen ;
					my $sparePercentHalf = $spare / ($wLen*0.95) *100 / 2 ;
					my $startOffset = 50 - $sparePercentHalf ;
					my $endOffset = 50 + $sparePercentHalf ;
					# five possible positions per way
					my $step = ($endOffset - $startOffset) / 5 ;
					my @positions = () ;
					my $actual = $startOffset ;
					while ($actual <= $endOffset) {
						my ($ref, $angle) = subWay (\@points, $lLen, "middle", $actual) ;
						my @way = @$ref ;
						my ($col) = lineCrossings (\@way) ;
						# calc quality of position. distance from middle and bend angles
						my $quality = $angle + abs (50 - $actual) ;
						if ($col == 0) { push @positions, ["middle", $actual, $quality] ; }
						$actual += $step ;
					}
					if (scalar @positions > 0) {
						$drawnLabels { $name } = 1 ;
						# sort by quality and take best one
						@positions = sort {$a->[2] <=> $b->[2]} @positions ;
						my ($pos) = shift @positions ;
						my ($ref, $angle) = subWay (\@points, $lLen, $pos->[0], $pos->[1]) ;
						my @finalWay = @$ref ;
						my $pathName = "Path" . $pathNumber ; $pathNumber++ ;
						push @svgOutputDef, svgElementPath ($pathName, @points) ;
						push @svgOutputPathText, svgElementPathTextAdvanced ($ruleData[$wayIndexLabelColor], $ruleData[$wayIndexLabelSize], 
							$ruleData[$wayIndexLabelFont], $name, $pathName, $ruleData[$wayIndexLabelOffset], $pos->[0], $pos->[1], $halo) ;
						occupyLines (\@finalWay) ;
					}
					else {
						$numWayLabelsOmitted++ ;
					}
				}
				else { # more than one label
					my $labelDrawn = 0 ;
					my $interval = int (100 / ($numLabels + 1)) ;
					my @positions = () ;
					for (my $i=1; $i<=$numLabels; $i++) {
						push @positions, $i * $interval ;
					}
			
					foreach my $position (@positions) {
						my ($refFinal, $angle) = subWay (\@points, $lLen, "middle", $position) ;
						my (@finalWay) = @$refFinal ;
						my ($collision) = lineCrossings (\@finalWay) ;
						if ($collision == 0) {
							$labelDrawn = 1 ;
							$drawnLabels { $name } = 1 ;
							my $pathName = "Path" . $pathNumber ; $pathNumber++ ;
							push @svgOutputDef, svgElementPath ($pathName, @finalWay) ;
							push @svgOutputPathText, svgElementPathTextAdvanced ($ruleData[$wayIndexLabelColor], $ruleData[$wayIndexLabelSize], 
								$ruleData[$wayIndexLabelFont], $name, $pathName, $ruleData[$wayIndexLabelOffset], "middle", 50, $halo) ;
							occupyLines (\@finalWay) ;
						}
						else {
							# print "INFO: $name labeled less often than desired.\n" ;
						}
					}
					if ($labelDrawn == 0) {
						$notDrawnLabels { $name } = 1 ;
					}
				}
			}
		}
	}
	my $labelFileName = $svgName ;
	$labelFileName =~ s/\.svg/_NotDrawnLabels.txt/ ;
	my $labelFile ;
	open ($labelFile, ">", $labelFileName) or die ("couldn't open label file $labelFileName") ;
	print $labelFile "Not drawn labels\n\n" ;
	foreach my $labelName (sort keys %notDrawnLabels) {
		if (!defined $drawnLabels { $labelName } ) {
			print $labelFile "$labelName\n" ;
		}
	}
	close ($labelFile) ;

}


sub occupyLines {
#
# store drawn lines and make quad tree entries
# accepts multiple coordinates that form a way
#
	my ($ref) = shift ;
	my @coordinates = @$ref ;

	for (my $i=0; $i<$#coordinates-2; $i+=2) {
		push @lines, [$coordinates[$i], $coordinates[$i+1], $coordinates[$i+2], $coordinates[$i+3]] ;
		# print "PUSHED $coordinates[$i], $coordinates[$i+1], $coordinates[$i+2], $coordinates[$i+3]\n" ;
		# drawWayPix ("black", 1, 0, @coordinates)

		$qtWayLabels->add ($#lines, $coordinates[$i], $coordinates[$i+1], $coordinates[$i+2], $coordinates[$i+3]) ;

	}
}


sub lineCrossings {
#
# checks for line collisions
# accepts multiple lines in form of multiple coordinates
#
	my ($ref) = shift ;
	my @coordinates = @$ref ;
	my @testLines = () ;

	for (my $i=0; $i<$#coordinates-2; $i+=2) {
		push @testLines, [$coordinates[$i], $coordinates[$i+1], $coordinates[$i+2], $coordinates[$i+3]] ;
	}

	# find area of way
	my ($found) = 0 ;
	my $xMin = 999999 ; my $xMax = 0 ;
	my $yMin = 999999 ; my $yMax = 0 ;
	foreach my $l1 (@testLines) {
		if ($l1->[0] > $xMax) { $xMax = $l1->[0] ; }
		if ($l1->[0] < $xMin) { $xMin = $l1->[0] ; }
		if ($l1->[1] > $yMax) { $yMax = $l1->[1] ; }
		if ($l1->[1] < $yMin) { $yMin = $l1->[1] ; }
	}
	
	# get indexes from quad tree
	my $ref2 = $qtWayLabels->getEnclosedObjects ($xMin, $yMin, $xMax, $yMax) ;
	# create array linesInArea
	my @linesInAreaIndex = @$ref2 ;
	my @linesInArea = () ;
	foreach my $lineNr (@linesInAreaIndex) {
		push @linesInArea, $lines[$lineNr] ;
	} 

	LABCR: foreach my $l1 (@testLines) {
		foreach my $l2 (@linesInArea) {
			my ($x, $y) = intersection (@$l1, @$l2) ;
			if (($x !=0) and ($y != 0)) {
				$found = 1 ;
				last LABCR ;
			}
		}
	}
	if ($found == 0) {
		return 0 ;
	}
	else {
		return 1 ;
	}	
}

sub triangleNode {
#
# get segment of segment as coordinates
# from start or from end of segment
#
	# 0 = start
	# 1 = end
	my ($x1, $y1, $x2, $y2, $len, $startEnd) = @_ ;
	my ($c) = sqrt ( ($x2-$x1)**2 + ($y2-$y1)**2) ;
	my $percent = $len / $c ;

	my ($x, $y) ;
	if ($startEnd == 0 ) {	
		$x = $x1 + ($x2-$x1)*$percent ;
		$y = $y1 + ($y2-$y1)*$percent ;
	}
	else {
		$x = $x2 - ($x2-$x1)*$percent ;
		$y = $y2 - ($y2-$y1)*$percent ;
	}
	return ($x, $y) ;
}


sub subWay {
#
# takes coordinates and label information and creates new way/path
# also calculates total angles / bends
#
	my ($ref, $labLen, $alignment, $position) = @_ ;
	my @coordinates = @$ref ;
	my @points ;
	my @dists ;
	my @angles = () ;

	for (my $i=0; $i < $#coordinates; $i+=2) {
		push @points, [$coordinates[$i],$coordinates[$i+1]] ;
	}

	$dists[0] = 0 ;
	my $dist = 0 ;
	if (scalar @points > 1) {
		for (my $i=1;$i<=$#points; $i++) {
			$dist = $dist + sqrt ( ($points[$i-1]->[0]-$points[$i]->[0])**2 + ($points[$i-1]->[1]-$points[$i]->[1])**2 ) ;
			$dists[$i] = $dist ;
		}			
	}

	# calc angles at nodes
	if (scalar @points > 2) {
		for (my $i=1;$i<$#points; $i++) {
			$angles[$i] = angleMapgen ($points[$i-1]->[0], $points[$i-1]->[1], $points[$i]->[0], $points[$i]->[1], $points[$i]->[0], $points[$i]->[1], $points[$i+1]->[0], $points[$i+1]->[1]) ;
		}			
	}

	my $wayLength = $dist ;
	my $refPoint = $wayLength / 100 * $position ;
	my $labelStart ; my $labelEnd ;
	if ($alignment eq "start") { # left
		$labelStart = $refPoint ;
		$labelEnd = $labelStart + $labLen ;
	}
	if ($alignment eq "end") { # right
		$labelEnd = $refPoint ;
		$labelStart = $labelEnd - $labLen ;
	}
	if ($alignment eq "middle") { # center
		$labelEnd = $refPoint + $labLen / 2 ;
		$labelStart = $refPoint - $labLen / 2 ;
	}

	# find start and end segments
	my $startSeg ; my $endSeg ;
	for (my $i=0; $i<$#points; $i++) {
		if ( ($dists[$i]<=$labelStart) and ($dists[$i+1]>=$labelStart) ) { $startSeg = $i ; }
		if ( ($dists[$i]<=$labelEnd) and ($dists[$i+1]>=$labelEnd) ) { $endSeg = $i ; }
	}

	my @finalWay = () ;
	my $finalAngle = 0 ;
	my ($sx, $sy) = triangleNode ($coordinates[$startSeg*2], $coordinates[$startSeg*2+1], $coordinates[$startSeg*2+2], $coordinates[$startSeg*2+3], $labelStart-$dists[$startSeg], 0) ;
	push @finalWay, $sx, $sy ;

	if ($startSeg != $endSeg) {
		for (my $i=$startSeg+1; $i<=$endSeg; $i++) { 
			push @finalWay, $coordinates[$i*2], $coordinates[$i*2+1] ; 
			$finalAngle += abs ($angles[$i]) ;
		}
	}

	my ($ex, $ey) = triangleNode ($coordinates[$endSeg*2], $coordinates[$endSeg*2+1], $coordinates[$endSeg*2+2], $coordinates[$endSeg*2+3], $labelEnd-$dists[$endSeg], 0) ;
	push @finalWay, $ex, $ey ;
	
	return (\@finalWay, $finalAngle) ;	
}

sub intersection {
#
# returns intersection point of two lines, else (0,0)
#
	my ($g1x1) = shift ;
	my ($g1y1) = shift ;
	my ($g1x2) = shift ;
	my ($g1y2) = shift ;
	
	my ($g2x1) = shift ;
	my ($g2y1) = shift ;
	my ($g2x2) = shift ;
	my ($g2y2) = shift ;

	if (($g1x1 == $g2x1) and ($g1y1 == $g2y1)) { # p1 = p1 ?
		return ($g1x1, $g1y1) ;
	}
	if (($g1x1 == $g2x2) and ($g1y1 == $g2y2)) { # p1 = p2 ?
		return ($g1x1, $g1y1) ;
	}
	if (($g1x2 == $g2x1) and ($g1y2 == $g2y1)) { # p2 = p1 ?
		return ($g1x2, $g1y2) ;
	}

	if (($g1x2 == $g2x2) and ($g1y2 == $g2y2)) { # p2 = p1 ?
		return ($g1x2, $g1y2) ;
	}

	my $g1m ;
	if ( ($g1x2-$g1x1) != 0 )  {
		$g1m = ($g1y2-$g1y1)/($g1x2-$g1x1) ; # steigungen
	}
	else {
		$g1m = 999999 ;
	}

	my $g2m ;
	if ( ($g2x2-$g2x1) != 0 ) {
		$g2m = ($g2y2-$g2y1)/($g2x2-$g2x1) ;
	}
	else {
		$g2m = 999999 ;
	}

	if ($g1m == $g2m) {   # parallel
		return (0, 0) ;
	}

	my ($g1b) = $g1y1 - $g1m * $g1x1 ; # abschnitte
	my ($g2b) = $g2y1 - $g2m * $g2x1 ;

	my ($sx) = ($g2b-$g1b) / ($g1m-$g2m) ;             # schnittpunkt
	my ($sy) = ($g1m*$g2b - $g2m*$g1b) / ($g1m-$g2m);

	my ($g1xmax) = max ($g1x1, $g1x2) ;
	my ($g1xmin) = min ($g1x1, $g1x2) ;	
	my ($g1ymax) = max ($g1y1, $g1y2) ;	
	my ($g1ymin) = min ($g1y1, $g1y2) ;	

	my ($g2xmax) = max ($g2x1, $g2x2) ;
	my ($g2xmin) = min ($g2x1, $g2x2) ;	
	my ($g2ymax) = max ($g2y1, $g2y2) ;	
	my ($g2ymin) = min ($g2y1, $g2y2) ;	

	if 	(($sx >= $g1xmin) and
		($sx >= $g2xmin) and
		($sx <= $g1xmax) and
		($sx <= $g2xmax) and
		($sy >= $g1ymin) and
		($sy >= $g2ymin) and
		($sy <= $g1ymax) and
		($sy <= $g2ymax)) {
		return ($sx, $sy) ;
	}
	else {
		return (0, 0) ;
	}
} 

sub angleMapgen {
#
# angle between lines/segments
#
	my ($g1x1) = shift ;
	my ($g1y1) = shift ;
	my ($g1x2) = shift ;
	my ($g1y2) = shift ;
	my ($g2x1) = shift ;
	my ($g2y1) = shift ;
	my ($g2x2) = shift ;
	my ($g2y2) = shift ;

	my $g1m ;
	if ( ($g1x2-$g1x1) != 0 )  {
		$g1m = ($g1y2-$g1y1)/($g1x2-$g1x1) ; # steigungen
	}
	else {
		$g1m = 999999999 ;
	}

	my $g2m ;
	if ( ($g2x2-$g2x1) != 0 ) {
		$g2m = ($g2y2-$g2y1)/($g2x2-$g2x1) ;
	}
	else {
		$g2m = 999999999 ;
	}

	if ($g1m == $g2m) {   # parallel
		return (0) ;
	}
	else {
		my $t1 = $g1m -$g2m ;
		my $t2 = 1 + $g1m * $g2m ;
		if ($t2 == 0) {
			return 90 ;
		}
		else {
			my $a = atan (abs ($t1/$t2)) / 3.141592654 * 180 ;
			return $a ;
		}
	}
} 


#------------------------------------------------------------------------------------------------------------


sub drawArea {
#
# draws an area like waterway=riverbank or landuse=forest. 
# pass color as string and nodes as list (x1, y1, x2, y2...) - real world coordinates
#
	my ($col, $icon, @nodes) = @_ ;
	my $i ;
	my @points = () ;
	
	for ($i=0; $i<$#nodes; $i+=2) {
		my ($x1, $y1) = convert ($nodes[$i], $nodes[$i+1]) ;
		push @points, $x1 ; push @points, $y1 ; 
	}
	push @svgOutputAreas, svgElementPolygonFilled ($col, $icon, @points) ;
}

sub drawAreaPix {
#
# draws an area like waterway=riverbank or landuse=forest. 
# pass color as string and nodes as list (x1, y1, x2, y2...) - pixels
# used for legend
#
	my ($col, $icon, @nodes) = @_ ;
	my $i ;
	my @points = () ;
	for ($i=0; $i<$#nodes; $i+=2) {
		my ($x1, $y1) = ($nodes[$i], $nodes[$i+1]) ;
		push @points, $x1 ; push @points, $y1 ; 
	}
	push @svgOutputPixel, svgElementPolygonFilled ($col, $icon, @points) ;
}

sub drawAreaMP {
#
# draws an area like waterway=riverbank or landuse=forest. 
# pass color as string and nodes as list (x1, y1, x2, y2...) - real world coordinates
#
# receives ARRAY of ARRAY of NODES LIST! NOT coordinates list like other functions
#
	my ($col, $icon, $ref, $refLon, $refLat) = @_ ;
	# my %lon = %$refLon ;
	# my %lat = %$refLat ;
	my @ways = @$ref ;
	my $i ;
	my @array = () ;

	foreach my $way (@ways) {	
		my @actual = @$way ;
		# print "drawAreaMP - actual ring/way: @actual\n" ; 
			my @points = () ;
		for ($i=0; $i<$#actual; $i++) { # without last node! SVG command 'z'!
			my ($x1, $y1) = convert ( $$refLon{$actual[$i]}, $$refLat{$actual[$i]} ) ;
			push @points, $x1 ; push @points, $y1 ; 
		}
		push @array, [@points] ;
		# print "drawAreaMP - array pushed: @points\n" ; 
	}

	push @svgOutputAreas, svgElementMultiPolygonFilled ($col, $icon, \@array) ;
}



sub drawRuler {
#
# draws ruler in top right corner, size is automatic
#
	my $col = shift ;

	my $B ; my $B2 ;
	my $L ; my $Lpix ;
	my $x ;
	my $text ;
	my $rx = $sizeX - scalePoints (scaleBase (80)) ;
	my $ry = scalePoints (scaleBase (60)) ; #v1.17
	# my $ry = scalePoints (scaleBase (80)) ;
	my $lineThickness = 8 ; # at 300dpi
	my $textSize = 40 ; # at 300 dpi
	my $textDist = 60 ; # at 300 dpi
	my $lineLen = 40 ; # at 300 dpi
		
	$B = $right - $left ; 				# in degrees
	$B2 = $B * cos ($top/360*3.14*2) * 111.1 ;	# in km
	$text = "50m" ; $x = 0.05 ;			# default length ruler

	if ($B2 > 0.5) {$text = "100m" ; $x = 0.1 ; }	# enlarge ruler
	if ($B2 > 1) {$text = "500m" ; $x = 0.5 ; }	# enlarge ruler
	if ($B2 > 5) {$text = "1km" ; $x = 1 ; }
	if ($B2 > 10) {$text = "5km" ; $x = 5 ; }
	if ($B2 > 50) {$text = "10km" ; $x = 10 ; }
	$L = $x / (cos ($top/360*3.14*2) * 111.1 ) ;	# length ruler in km
	$Lpix = $L / $B * $sizeX ;			# length ruler in pixels

	push @svgOutputText, svgElementLine ($rx-$Lpix,$ry,$rx,$ry, $col, scalePoints( scaleBase ($lineThickness) ) ) ;
	push @svgOutputText, svgElementLine ($rx-$Lpix,$ry,$rx-$Lpix,$ry+scalePoints(scaleBase($lineLen)), $col, scalePoints( scaleBase ($lineThickness) ) ) ;
	push @svgOutputText, svgElementLine ($rx,$ry,$rx,$ry+scalePoints(scaleBase($lineLen)), $col, scalePoints( scaleBase ($lineThickness) )) ;
	push @svgOutputText, svgElementLine ($rx-$Lpix/2,$ry,$rx-$Lpix/2,$ry+scalePoints(scaleBase($lineLen/2)), $col, scalePoints( scaleBase ($lineThickness) ) ) ;
	push @svgOutputText, svgElementText ($rx-$Lpix, $ry+scalePoints(scaleBase($textDist)), $text, scalePoints(scaleBase($textSize)), "sans-serif", $col) ;
}

sub drawGrid {
#
# draw grid on top of map. receives number of parts in x/lon direction
#
	my ($number, $color) = @_ ;
	my $part = $sizeX / $number ;
	my $numY = $sizeY / $part ;
	# vertical lines
	for (my $i = 1; $i <= $number; $i++) {
		drawWayPixGrid ($color, 1, $dashStyle{1}, $i*$part, 0, $i*$part, $sizeY) ;
		drawTextPixGrid (($i-1)*$part+$part/2, scalePoints(scaleBase(160)), chr($i+64), $color, scalePoints(scaleBase(60))) ;
	}
	# hor. lines
	for (my $i = 1; $i <= $numY; $i++) {
		drawWayPixGrid ($color, 1, $dashStyle{1}, 0, $i*$part, $sizeX, $i*$part) ;
		drawTextPixGrid (scalePoints(scaleBase(20)), ($i-1)*$part+$part/2, $i, $color, scalePoints(scaleBase(60))) ;
	}
}



#####
# SVG
#####


sub writeSVG {
#
# writes svg elemets collected so far to file
#
	my ($fileName) = shift ;
	my $file ;
	my ($paper, $w, $h) = fitsPaper ($dpi) ;

	open ($file, ">", $fileName) || die "can't open svg output file";
	print $file "<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"no\"?>\n" ;
	print $file "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\" >\n" ;

	my ($svg) = "<svg version=\"1.1\" baseProfile=\"full\" xmlns=\"http://www.w3.org/2000/svg\" " ;
	$svg .= "xmlns:xlink=\"http://www.w3.org/1999/xlink\" xmlns:ev=\"http://www.w3.org/2001/xml-events\" " ;
	$svg .= "width=\"$w" . "cm\" height=\"$h" . "cm\" viewBox=\"0 0 $sizeX $sizeY\">\n" ;
	print $file $svg ;

	print $file "<rect width=\"$sizeX\" height=\"$sizeY\" y=\"0\" x=\"0\" fill=\"#ffffff\" />\n" ;

	print $file "<defs>\n" ;
	foreach (@svgOutputDef) { print $file $_, "\n" ; }
	print $file "</defs>\n" ;

	print $file "<g id=\"Areas\">\n" ;
	foreach (@svgOutputAreas) { print $file $_, "\n" ; }
	print $file "</g>\n" ;

	print $file "<g id=\"Ways\">\n" ;
	foreach my $layer (sort {$a <=> $b} (keys %svgOutputWays)) {
		foreach (@{$svgOutputWays{$layer}}) { print $file $_, "\n" ; }
	}
	print $file "</g>\n" ;

	print $file "<g id=\"Nodes\">\n" ;
	foreach my $layer (sort {$a <=> $b} (keys %svgOutputNodes)) {
		foreach (@{$svgOutputNodes{$layer}}) { print $file $_, "\n" ; }
	}
	print $file "</g>\n" ;


	print $file "<g id=\"Routes\">\n" ;
	foreach (@svgOutputRoutes) { print $file $_, "\n" ; }
	print $file "</g>\n" ;

	print $file "<g id=\"RouteStops\">\n" ;
	foreach (@svgOutputRouteStops) { print $file $_, "\n" ; }
	print $file "</g>\n" ;

	print $file "<g id=\"Text\">\n" ;
	foreach (@svgOutputText) { print $file $_, "\n" ; }
	print $file "</g>\n" ;

	print $file "<g id=\"Icons\">\n" ;
	foreach (@svgOutputIcons) { print $file $_, "\n" ; }
	print $file "</g>\n" ;

	print $file "<g id=\"Labels\">\n" ;
	foreach (@svgOutputPathText) { print $file $_, "\n" ; }
	print $file "</g>\n" ;

	print $file "<g id=\"Grid\">\n" ;
	foreach (@svgOutputPixelGrid) { print $file $_, "\n" ; }
	print $file "</g>\n" ;

	print $file "<g id=\"Pixels\">\n" ;
	foreach (@svgOutputPixel) { print $file $_, "\n" ; }
	print $file "</g>\n" ;

	print $file "</svg>\n" ;
	close ($file) ;
}

sub svgElementText {
#
# creates string with svg element incl utf-8 encoding
#
	my ($x, $y, $text, $size, $font, $col) = @_ ; 
	my $svg = "<text x=\"" . $x . "\" y=\"" . $y . 
		"\" font-size=\"" . $size . 
		"\" font-family=\"" . $font . 
		"\" fill=\"" . $col . 
		"\">" . $text . "</text>" ;
	return $svg ;
}

sub svgElementCircleFilled {
#
# draws circle filled
#
	my ($x, $y, $size, $col) = @_ ;
	my $svg = "<circle cx=\"" . $x . "\" cy=\"" . $y . "\" r=\"" . $size . "\" fill=\"" . $col  . "\" />" ;
	return $svg ;
}

sub svgElementCircle {
#
# draws not filled circle / dot
#
	my ($x, $y, $radius, $size, $col) = @_ ;
	my $svg = "<circle cx=\"" . $x . "\" cy=\"" . $y . "\" r=\"" . $radius . "\" fill=\"none\" stroke=\"" . $col  . "\" stroke-width=\"$size\" />" ;
	return $svg ;
}

sub svgElementLine {
#
# draws line between two points
#
	my ($x1, $y1, $x2, $y2, $col, $size) = @_ ;
	my $svg = "<polyline points=\"" . $x1 . "," . $y1 . " " . $x2 . "," . $y2 . "\" stroke=\"" . $col . "\" stroke-width=\"" . $size . "\"/>" ;
	return $svg ;
}




sub svgElementPolyline {
#
# draws way to svg
#
	my ($col, $size, $dash, @points) = @_ ;

	my $refp = simplifyPoints (\@points) ;
	@points = @$refp ;


	my $svg = "<polyline points=\"" ;
	my $i ;
	for ($i=0; $i<scalar(@points)-1; $i+=2) {
		$svg = $svg . $points[$i] . "," . $points[$i+1] . " " ;
	}
	if ($dash eq "none") { 
		my $lc = "round" ;
		$svg = $svg . "\" stroke=\"" . $col . "\" stroke-width=\"" . $size . "\" stroke-linecap=\"" . $lc . "\" stroke-linejoin=\"" . $lineJoin . "\" fill=\"none\" />" ;
	}
	else {
		my $lc = "" ; my $ds = "" ;
		($lc, $ds) = getDashElements ($dash) ;
		$svg = $svg . "\" stroke=\"" . $col . "\" stroke-width=\"" . $size . "\" stroke-linecap=\"" . $lc . "\" stroke-linejoin=\"" . $lineJoin . "\" stroke-dasharray=\"" . $ds . "\" fill=\"none\" />" ;
	}
	return $svg ;
}


sub svgElementPolylineBridge {
#
# draws way to svg
#
	my ($col, $size, $dash, @points) = @_ ;

	my $refp = simplifyPoints (\@points) ;
	@points = @$refp ;

	my $svg = "<polyline points=\"" ;
	my $i ;
	for ($i=0; $i<scalar(@points)-1; $i+=2) {
		$svg = $svg . $points[$i] . "," . $points[$i+1] . " " ;
	}
	if ($dash eq "none") { 
		$svg = $svg . "\" stroke=\"" . $col . "\" stroke-width=\"" . $size . "\" fill=\"none\" />" ;
	}
	else {
		my $lc = "" ; my $ds ;
		($lc, $ds) = getDashElements ($dash) ;
		$svg = $svg . "\" stroke=\"" . $col . "\" stroke-width=\"" . $size . "\" stroke-linecap=\"" . $lc . "\" stroke-dasharray=\"" . $ds . "\" fill=\"none\" />" ;
	}
	return $svg ;
}



sub getDashElements {
	my $string = shift ;
	my @a = split /,/, $string ;
	my $cap = pop @a ;
	my $ds = "" ; my $first = 1 ;
	foreach my $v (@a) {
		if ($first) {
			$first = 0 ;
		}
		else {
			$ds .= "," ;
		}
		$ds .= $v ;
	}
	# print "GETDE $cap, $ds\n" ;
	return ($cap, $ds) ;
}



sub svgElementPath {
#
# creates path element for later use with textPath
#
	my ($pathName, @points) = @_ ;

	my $refp = simplifyPoints (\@points) ;
	@points = @$refp ;

	my $svg = "<path id=\"" . $pathName . "\" d=\"M " ;
	my $i ;
	my $first = 1 ;
	for ($i=0; $i<scalar(@points); $i+=2) {
		if ($first) {
			$svg = $svg . $points[$i] . "," . $points[$i+1] . " " ;
			$first = 0 ;
		}
		else {
			$svg = $svg . "L " . $points[$i] . "," . $points[$i+1] . " " ;
		}
	}
	$svg = $svg . "\" />\n" ;
}


sub svgElementPathTextAdvanced {
#
# draws text to path element; anchors: start, middle, end
#
	my ($col, $size, $font, $text, $pathName, $tSpan, $alignment, $offset, $halo) = @_ ;

	my $svg = "<text font-family=\"" . $font . "\" " ;
	$svg = $svg . "font-size=\"" . $size . "\" " ;

	if ($halo > 0) {
		$svg = $svg . "font-weight=\"bold\" " ;
		$svg = $svg . "stroke=\"white\" " ;
		$svg = $svg . "stroke-width=\"" . $halo . "\" " ;
		$svg = $svg . "opacity=\"90\%\" " ;
	}

	$svg = $svg . "fill=\"" . $col . "\" >\n" ;
	$svg = $svg . "<textPath xlink:href=\"#" . $pathName . "\" text-anchor=\"" . $alignment . "\" startOffset=\"" . $offset . "%\" >\n" ;
	$svg = $svg . "<tspan dy=\"" . $tSpan . "\" >" . $text . " </tspan>\n" ;
	$svg = $svg . "</textPath>\n</text>\n" ;
	return $svg ;
}


sub svgElementPolygonFilled {
#
# draws areas in svg, filled with color 
#
	my ($col, $icon, @points) = @_ ;

	my $refp = simplifyPoints (\@points) ;
	@points = @$refp ;

	my $i ;
	my $svg ;
	if (defined $areaDef{$icon}) {
		$svg = "<path fill-rule=\"evenodd\" style=\"fill:url(" . $areaDef{$icon} . ")\" d=\"" ;
		# print "AREA POLYGON with icon $icon drawn\n" ;
	}
	else {
		$svg = "<path fill-rule=\"evenodd\" fill=\"" . $col . "\" d=\"" ;
	}


	for ($i=0; $i<scalar(@points); $i+=2) {
		if ($i == 0) { $svg .= " M " ; } else { $svg .= " L " ; }
		$svg = $svg . $points[$i] . " " . $points[$i+1] ;
	}
	$svg .= " z" ;




#	for ($i=0; $i<scalar(@points); $i+=2) {
#		$svg = $svg . $points[$i] . "," . $points[$i+1] . " " ;
#	}
	$svg = $svg . "\" />" ;
	return $svg ;
}

sub svgElementMultiPolygonFilled {
#
# draws mp in svg, filled with color. accepts holes. receives ARRAY of ARRAY of coordinates
#
	my ($col, $icon, $ref) = @_ ;

	my @ways = @$ref ;
	my $i ;
	my $svg ;
	if (defined $areaDef{$icon}) {
		$svg = "<path fill-rule=\"evenodd\" style=\"fill:url(" . $areaDef{$icon} . ")\" d=\"" ;
		# print "AREA PATH with icon $icon drawn\n" ;
	}
	else {
		$svg = "<path fill-rule=\"evenodd\" fill=\"" . $col . "\" d=\"" ;
	}
	
	foreach my $way (@ways) {
		my @actual = @$way ;
		# print "svg - actual: @actual\n" ;
		for ($i=0; $i<scalar(@actual); $i+=2) {
			if ($i == 0) { $svg .= " M " ; } else { $svg .= " L " ; }
			$svg = $svg . $actual[$i] . " " . $actual[$i+1] ;
		}
		$svg .= " z" ;
		# print "svg - text = $svg\n" ; 
	}

	$svg = $svg . "\" />" ;
	# print "svg - text = $svg\n" ; 
	return $svg ;
}

sub createLabel {
#
# takes @tags and labelKey(s) from style file and creates labelTextTotal and array of labels for directory
# takes more keys in one string - using a separator. 
#
# � all listed keys will be searched for and values be concatenated
# # first of found keys will be used to select value
# "name�ref" will return all values if given
# "name#ref" will return name, if given. if no name is given, ref will be used. none given, no text
#
	my ($ref1, $styleLabelText, $lon, $lat) = @_ ;
	my @tags = @$ref1 ;
	my @keys ;
	my @labels = () ;
	my $labelTextTotal = "" ; 

	if (grep /!/, $styleLabelText) { # AND
		@keys = split ( /!/, $styleLabelText) ;
		# print "par found: $styleLabelText; @keys\n" ;
		for (my $i=0; $i<=$#keys; $i++) {
			if ($keys[$i] eq "_lat") { push @labels, $lat ; } 
			if ($keys[$i] eq "_lon") { push @labels, $lon ; } 
			foreach my $tag (@tags) {
				if ($tag->[0] eq $keys[$i]) {
					push @labels, $tag->[1] ;
				}
			}
		}
		$labelTextTotal = "" ;
		foreach my $label (@labels) { $labelTextTotal .= $label . " " ; }
	}
	else { # PRIO
		@keys = split ( /#/, $styleLabelText) ;
		my $i = 0 ; my $found = 0 ;
		while ( ($i<=$#keys) and ($found == 0) ) {
			if ($keys[$i] eq "_lat") { push @labels, $lat ; $found = 1 ; $labelTextTotal = $lat ; } 
			if ($keys[$i] eq "_lon") { push @labels, $lon ; $found = 1 ; $labelTextTotal = $lon ; } 
			foreach my $tag (@tags) {
				if ($tag->[0] eq $keys[$i]) {
					push @labels, $tag->[1] ;
					$labelTextTotal = $tag->[1] ;
					$found = 1 ;
				}
			}
			$i++ ;
		}		
	}
	return ( $labelTextTotal, \@labels) ;
}

sub center {
#
# calculate center of area by averageing lons/lats. could be smarter because result could be outside of area! TODO
#
	my @nodes = @_ ;
	my $x = 0 ;
	my $y = 0 ;
	my $num = 0 ;

	while (scalar @nodes > 0) { 
		my $y1 = pop @nodes ;
		my $x1 = pop @nodes ;
		$x += $x1 ;
		$y += $y1 ;
		$num++ ;
	}
	$x = $x / $num ;
	$y = $y / $num ;
	return ($x, $y) ;
}

sub printScale {
#
# print scale based on dpi and global variables left, right etc.
#
	my ($dpi, $color) = @_ ;

	my $dist = distance ($left, $bottom, $right, $bottom) ;
	my $inches = $sizeX / $dpi ;
	my $cm = $inches * 2.54 ;
	my $scale = int ( $dist / ($cm/100/1000)  ) ;
	$scale = int ($scale / 100) * 100 ;
	my $text = "1 : $scale" ;
	# sizes for 300 dpi
	my $posX = 350 ;
	my $posY = 50 ;
	my $size = 56 ;
	drawTextPix (
		$sizeX-scalePoints( scaleBase($posX) ), 
		scalePoints( scaleBase($posY) ), 
		$text, $color, 
		scalePoints( scaleBase ($size) ), "sans-serif"
	) ;
}


sub getScale {
#
# calcs scale of map
#
	my ($dpi) = shift ;

	my $dist = distance ($left, $bottom, $right, $bottom) ;
	my $inches = $sizeX / $dpi ;
	my $cm = $inches * 2.54 ;
	my $scale = int ( $dist / ($cm/100/1000)  ) ;
	$scale = int ($scale / 100) * 100 ;

	return ($scale) ;
}

sub fitsPaper {
#
# takes dpi and calculates on what paper size the map will fit. sizes are taken from global variables
#
	my ($dpi) = shift ;



	my @sizes = () ;
	my $width = $sizeX / $dpi * 2.54 ;
	my $height = $sizeY / $dpi * 2.54 ;
	my $paper = "" ;
	push @sizes, ["4A0", 168.2, 237.8] ;
	push @sizes, ["2A0", 118.9, 168.2] ;
	push @sizes, ["A0", 84.1, 118.9] ;
	push @sizes, ["A1", 59.4, 84.1] ;
	push @sizes, ["A2", 42, 59.4] ;
	push @sizes, ["A3", 29.7, 42] ;
	push @sizes, ["A4", 21, 29.7] ;
	push @sizes, ["A5", 14.8, 21] ;
	push @sizes, ["A6", 10.5, 14.8] ;
	push @sizes, ["A7", 7.4, 10.5] ;
	push @sizes, ["none", 0, 0] ;

	foreach my $size (@sizes) {
		if ( ( ($width<=$size->[1]) and ($height<=$size->[2]) ) or ( ($width<=$size->[2]) and ($height<=$size->[1]) ) ) {
			$paper = $size->[0] ;
		}
	}

	return ($paper, $width, $height) ;
}




sub drawCoords {
#
# draws coordinates grid on map
#
	my ($exp, $color) = @_ ;
	my $step = 10 ** $exp ;

	# vert. lines
	my $start = int ($left / $step) + 1 ;
	my $actual = $start * $step ;
	while ($actual < $right) {
		# print "actualX: $actual\n" ;
		my ($x1, $y1) = convert ($actual, 0) ;
		drawTextPixGrid ($x1+scalePoints(scaleBase(10)), $sizeY-scalePoints(scaleBase(50)), $actual, $color, scalePoints(scaleBase(40))) ;
		drawWayPixGrid ($color, 1, "none", ($x1, 0, $x1, $sizeY) ) ;
		$actual += $step ;
	}

	# hor lines
	$start = int ($bottom / $step) + 1 ;
	$actual = $start * $step ;
	while ($actual < $top) {
		# print "actualY: $actual\n" ;
		my ($x1, $y1) = convert (0, $actual) ;
		drawTextPixGrid ($sizeX-scalePoints(scaleBase(180)), $y1+scalePoints(scaleBase(30)), $actual, $color, scalePoints(scaleBase(40))) ;
		drawWayPixGrid ($color, 1, "none", (0, $y1, $sizeX, $y1) ) ;
		$actual += $step ;
	}
}


sub getValue {
#
# gets value of a certain tag
#
	my ($key, $ref) = @_ ;
	my @relationTags = @$ref ;

	my $value = "" ;
	foreach my $tag (@relationTags) {
		if ($tag->[0] eq $key) { $value = $tag->[1] ; }
	}
	return ($value) ;
}


sub drawWayRoute {
#
# draws way as a line at given real world coordinates. nodes have to be passed as array ($lon, $lat, $lon, $lat...)
# $size = thickness
#
	my ($col, $size, $dash, $opacity, @nodes) = @_ ;
	my $i ;
	my @points = () ;

	for ($i=0; $i<$#nodes; $i+=2) {
		my ($x, $y) = convert ($nodes[$i], $nodes[$i+1]) ;
		push @points, $x ; push @points, $y ; 
	}
	push @svgOutputRoutes, svgElementPolylineOpacity ($col, $size, $dash, $opacity, @points) ;
}


sub svgElementPolylineOpacity {
#
# draws way to svg with opacity; for routes
#
	my ($col, $size, $dash, $opacity, @points) = @_ ;

	my $refp = simplifyPoints (\@points) ;
	@points = @$refp ;


	my $svg = "<polyline points=\"" ;
	my $i ;
	for ($i=0; $i<scalar(@points)-1; $i+=2) {
		$svg = $svg . $points[$i] . "," . $points[$i+1] . " " ;
	}
	if ($dash eq "none") { 
		my $lc = "round" ;
		$svg = $svg . "\" stroke=\"" . $col . 
			"\" stroke-width=\"" . $size . 
			"\" stroke-opacity=\"" . $opacity . 
			"\" stroke-linecap=\"" . $lc . 
			"\" stroke-linejoin=\"" . $lineJoin . "\" fill=\"none\" />" ;
	}
	else {
		my $lc = "" ; my $ds = "" ;
		($lc, $ds) = getDashElements ($dash) ;
		$svg = $svg . "\" stroke=\"" . $col . 
			"\" stroke-width=\"" . $size . 
			"\" stroke-opacity=\"" . $opacity . 
			"\" stroke-linecap=\"" . $lc . 
			"\" stroke-linejoin=\"" . $lineJoin . 
			"\" stroke-dasharray=\"" . $ds . 
			"\" fill=\"none\" />" ;
	}
	return $svg ;
}


sub addAreaIcon {
#
# initial collection of area icons 
#
	my $fileNameOriginal = shift ;
	# print "AREA: $fileNameOriginal\n" ;
	my $result = open (my $file, "<", $fileNameOriginal) ;
	close ($file) ;
	if ($result) {
		my ($x, $y) ;
		if (grep /.svg/, $fileNameOriginal) {
			($x, $y) = sizeSVG ($fileNameOriginal) ;
			if ( ($x == 0) or ($y == 0) ) { 
				$x = 32 ; $y = 32 ; 
				print "WARNING: size of file $fileNameOriginal could not be determined. Set to 32px x 32px\n" ;
			} 
		}

		if (grep /.png/, $fileNameOriginal) {
			($x, $y) = sizePNG ($fileNameOriginal) ;
		}

		if (!defined $areaDef{$fileNameOriginal}) {

			my $x1 = scalePoints( $x ) ; # scale area icons 
			my $y1 = scalePoints( $y ) ;
			my $fx = $x1 / $x ;
			my $fy = $y1 / $y ;
			
			# add defs to svg output
			my $defName = "A" . $areaNum ;
			# print "INFO area icon $fileNameOriginal, $defName, $x, $y --- $x1, $y1 --- $fx, $fy --- processed.\n" ;
			$areaNum++ ;

			my $svgElement = "<pattern id=\"" . $defName . "\" width=\"" . $x . "\" height=\"" . $y . "\" " ;
			$svgElement .= "patternTransform=\"translate(0,0) scale(" . $fx . "," . $fy . ")\" \n" ;
			$svgElement .= "patternUnits=\"userSpaceOnUse\">\n" ;
			$svgElement .= "  <image xlink:href=\"" . $fileNameOriginal . "\"/>\n" ;
			$svgElement .= "</pattern>\n" ;
			push @svgOutputDef, $svgElement ;
			$defName = "#" . $defName ;
			$areaDef{$fileNameOriginal} = $defName ;
		}
	}
	else {
		print "WARNING: area icon $fileNameOriginal not found!\n" ;
	}
}




sub svgEle {
#
# creates svg element string
#
	my ($a, $b) = @_ ;
	my $out = $a . "=\"" . $b . "\" " ;
	return ($out)
}



sub initOneways {
#
# write marker defs to svg 
#
	my $color = shift ;
	my $markerSize = scalePoints (scaleBase (20)) ;

	push @svgOutputDef, "<marker id=\"Arrow1\"" ;
	push @svgOutputDef, "viewBox=\"0 0 10 10\" refX=\"5\" refY=\"5\"" ;
	push @svgOutputDef, "markerUnits=\"strokeWidth\"" ;
	push @svgOutputDef, "markerWidth=\"" . $markerSize . "\" markerHeight=\"" . $markerSize . "\"" ;
	push @svgOutputDef, "orient=\"auto\">" ;
	push @svgOutputDef, "<path d=\"M 0 4 L 6 4 L 6 2 L 10 5 L 6 8 L 6 6 L 0 6 Z\" fill=\"" . $color .  "\" />" ;
	push @svgOutputDef, "</marker>" ;
}


sub addOnewayArrows {
#
# adds oneway arrows to new pathes
#
	my ($wayNodesRef, $lonRef, $latRef, $direction, $thickness, $color, $layer) = @_ ;
	my @wayNodes = @$wayNodesRef ;
	my $minDist = scalePoints(scaleBase(25)) ;
	# print "OW: mindist = $minDist\n" ;

	if ($direction == -1) { @wayNodes = reverse @wayNodes ; }

	# create new pathes with new nodes
	for (my $i=0; $i<scalar(@wayNodes)-1;$i++) {
		my ($x1, $y1) = convert ($$lonRef{$wayNodes[$i]}, $$latRef{$wayNodes[$i]}) ;
		my ($x2, $y2) = convert ($$lonRef{$wayNodes[$i+1]}, $$latRef{$wayNodes[$i+1]}) ;
		my $xn = ($x2+$x1) / 2 ;
		my $yn = ($y2+$y1) / 2 ;
		if (sqrt (($x2-$x1)**2+($y2-$y1)**2) > $minDist) {
			# create path
			# use path
			my $svg = "<path d=\"M $x1 $y1 L $xn $yn L $x2 $y2\" fill=\"none\" marker-mid=\"url(#Arrow1)\" />" ;
			
			push @{$svgOutputWays{$layer+$thickness/100}}, $svg ;
		}
	}
}

sub declutterStat {
#
# creates print string with clutter/declutter information
#
	my $perc1 ;
	my $perc2 ;
	my $perc3 ;
	my $perc4 ;
	if ($numIcons != 0) {
		$perc1 = int ($numIconsMoved / $numIcons * 100) ;
		$perc2 = int ($numIconsOmitted / $numIcons * 100) ;
	}
	else {
		$perc1 = 0 ;
		$perc2 = 0 ;
	}
	if ($numLabels != 0) {
		$perc3 = int ($numLabelsMoved / $numLabels * 100) ;
		$perc4 = int ($numLabelsOmitted / $numLabels * 100) ;
	}
	else {
		$perc3 = 0 ;
		$perc4 = 0 ;
	}

	my $out = "$numIcons icons drawn.\n" ; 
	$out .= "  $numIconsMoved moved. ($perc1 %)\n" ;
	$out .= "  $numIconsOmitted omitted (possibly with label!). ($perc2 %)\n" ;

	$out .= "$numLabels labels drawn.\n" ; 
	$out .= "  $numLabelsMoved moved. ($perc3 %)\n" ;
	$out .= "  $numLabelsOmitted omitted. ($perc4 %)\n\n" ;
	$out .= "$numWayLabelsOmitted way labels omitted because way was too short, collision or declutter.\n" ;


}

sub placeLabelAndIcon {
#
# intelligent icon and label placement alg.
#
	my ($lon, $lat, $offset, $thickness, $text, $color, $textSize, $font, $ppc, $icon, $iconSizeX, $iconSizeY, $allowIconMove, $halo) = @_ ;

	my ($x, $y) = convert ($lon, $lat) ; # center !
	$y = $y + $offset ;

	my ($ref) = splitLabel ($text) ;
	my (@lines) = @$ref ;
	my $numLines = scalar @lines ;
	my $maxTextLenPix = 0 ;
	my $orientation = "" ;
	my $lineDist = 2 ;
	my $tries = 0 ;

	foreach my $line (@lines) {
		my $len = length ($line) * $ppc / 10 * $textSize ; # in pixels
		if ($len > $maxTextLenPix) { $maxTextLenPix = $len ; }
	}
	my $spaceTextX = $maxTextLenPix ;
	my $spaceTextY = $numLines * ($lineDist+$textSize) ;


	if ($icon ne "none") {
		$numIcons++ ;
		# space for icon?
			my $sizeX1 = $iconSizeX ; if ($sizeX1 == 0) { $sizeX1 = 20 ; }
			my $sizeY1 = $iconSizeY ; if ($sizeY1 == 0) { $sizeY1 = 20 ; }
			my $iconX = $x - $sizeX1/2 ; # top left corner
			my $iconY = $y - $sizeY1/2 ; 

			my @shifts = (0) ;
			if ($allowIconMove eq "1") {
				@shifts = ( 0, scalePoints(scaleBase(-15)), scalePoints(scaleBase(15)) ) ;
			}
			my $posFound = 0 ; my $posCount = 0 ;
			LABAB: foreach my $xShift (@shifts) {
				foreach my $yShift (@shifts) {
					$posCount++ ;
					if ( ! areaOccupied ($iconX+$xShift, $iconX+$sizeX1+$xShift, $iconY+$sizeY1+$yShift, $iconY+$yShift) ) {
						push @svgOutputIcons, svgElementIcon ($iconX+$xShift, $iconY+$yShift, $icon, $sizeX1, $sizeY1) ;
						occupyArea ($iconX+$xShift, $iconX+$sizeX1+$xShift, $iconY+$sizeY1+$yShift, $iconY+$yShift) ;
						$posFound = 1 ;
						if ($posCount > 1) { $numIconsMoved++ ; }
						$iconX = $iconX + $xShift ; # for later use with label
						$iconY = $iconY + $yShift ;
						last LABAB ;
					}
				}
			}
			if ($posFound == 1) {

				# label text?
				if ($text ne "") {
					$numLabels++ ;


					$sizeX1 += 1 ; $sizeY1 += 1 ;

					my ($x1, $x2, $y1, $y2) ;
					# $x, $y centered 
					# yes, check if space for label, choose position, draw
					# no, count omitted text

					my @positions = () ; my $positionFound = 0 ;
					# pos 1 centered below
					$x1 = $x - $spaceTextX/2 ; $x2 = $x + $spaceTextX/2 ; $y1 = $y + $sizeY1/2 + $spaceTextY ; $y2 = $y + $sizeY1/2 ; $orientation = "centered" ; 
					push @positions, [$x1, $x2, $y1, $y2, $orientation] ;

					# pos 2/3 to the right, bottom, top
					$x1 = $x + $sizeX1/2 ; $x2 = $x + $sizeX1/2 + $spaceTextX ; $y1 = $y + $sizeY1/2 ; $y2 = $y1 - $spaceTextY ; $orientation = "left" ; 
					push @positions, [$x1, $x2, $y1, $y2, $orientation] ;
					$x1 = $x + $sizeX1/2 ; $x2 = $x + $sizeX1/2 + $spaceTextX ; $y2 = $y - $sizeY1/2 ; $y1 = $y2 + $spaceTextY ; $orientation = "left" ; 
					push @positions, [$x1, $x2, $y1, $y2, $orientation] ;

					# pos 4 centered upon
					$x1 = $x - $spaceTextX/2 ; $x2 = $x + $spaceTextX/2 ; $y1 = $y - $sizeY1/2 ; $y2 = $y - $sizeY1/2 - $spaceTextY ; $orientation = "centered" ; 
					push @positions, [$x1, $x2, $y1, $y2, $orientation] ;

					# pos 5/6 to the right, below and upon
					$x1 = $x + $sizeX1/2 ; $x2 = $x + $sizeX1/2 + $spaceTextX ; $y2 = $y + $sizeY1/2 ; $y1 = $y2 + $spaceTextY ; $orientation = "left" ; 
					push @positions, [$x1, $x2, $y1, $y2, $orientation] ;
					$x1 = $x + $sizeX1/2 ; $x2 = $x + $sizeX1/2 + $spaceTextX ; $y1 = $y - $sizeY1/2 ; $y2 = $y1 - $spaceTextY ; $orientation = "left" ; 
					push @positions, [$x1, $x2, $y1, $y2, $orientation] ;

					# left normal, bottom, top
					$x1 = $x - $sizeX1/2 - $spaceTextX ; $x2 = $x - $sizeX1/2 ; $y1 = $y + $sizeY1/2 ; $y2 = $y1 - $spaceTextY ; $orientation = "right" ; 
					push @positions, [$x1, $x2, $y1, $y2, $orientation] ;
					$x1 = $x - $sizeX1/2 - $spaceTextX ; $x2 = $x - $sizeX1/2 ; $y2 = $y - $sizeY1/2 ; $y1 = $y2 + $spaceTextY ; $orientation = "right" ; 
					push @positions, [$x1, $x2, $y1, $y2, $orientation] ;

					# left corners, bottom, top
					$x1 = $x - $sizeX1/2 - $spaceTextX ; $x2 = $x - $sizeX1/2 ; $y2 = $y + $sizeY1/2 ; $y1 = $y2 + $spaceTextY ; $orientation = "right" ; 
					push @positions, [$x1, $x2, $y1, $y2, $orientation] ;
					$x1 = $x - $sizeX1/2 - $spaceTextX ; $x2 = $x - $sizeX1/2 ; $y1 = $y - $sizeY1/2 ; $y2 = $y1 - $spaceTextY ; $orientation = "right" ; 
					push @positions, [$x1, $x2, $y1, $y2, $orientation] ;


					$tries = 0 ;
					LABB: foreach my $pos (@positions) {
						$tries++ ;
						$positionFound = checkAndDrawText ($pos->[0], $pos->[1], $pos->[2], $pos->[3], $pos->[4], $numLines, \@lines, $color, $textSize, $font, $lineDist, $halo) ;
						if ($positionFound == 1) {
							last LABB ;
						}
					}
					if ($positionFound == 0) { $numLabelsOmitted++ ; }
					if ($tries > 1) { $numLabelsMoved++ ; }
				}
			}
			else {
				# no, count omitted
				$numIconsOmitted++ ;
			}
	}
	else { # only text
		my ($x1, $x2, $y1, $y2) ;
		# x1, x2, y1, y2
		# left, right, bottom, top		
		# choose space for text, draw
		# count omitted

		$numLabels++ ;
		my @positions = () ;
		$x1 = $x + $thickness ; $x2 = $x + $thickness + $spaceTextX ; $y1 = $y ; $y2 = $y - $spaceTextY ; $orientation = "left" ; 
		push @positions, [$x1, $x2, $y1, $y2, $orientation] ;
		$x1 = $x + $thickness ; $x2 = $x + $thickness + $spaceTextX ; $y1 = $y + $spaceTextY ; $y2 = $y ; $orientation = "left" ; 
		push @positions, [$x1, $x2, $y1, $y2, $orientation] ;

		$x1 = $x - ($thickness + $spaceTextX) ; $x2 = $x - $thickness ; $y1 = $y ; $y2 = $y - $spaceTextY ; $orientation = "right" ; 
		push @positions, [$x1, $x2, $y1, $y2, $orientation] ;
		$x1 = $x - ($thickness + $spaceTextX) ; $x2 = $x - $thickness ; $y1 = $y ; $y2 = $y - $spaceTextY ; $orientation = "right" ; 
		push @positions, [$x1, $x2, $y1, $y2, $orientation] ;

		$x1 = $x - $spaceTextX/2 ; $x2 = $x + $spaceTextX/2 ; $y1 = $y - $thickness ; $y2 = $y - ($thickness + $spaceTextY) ; $orientation = "centered" ; 
		push @positions, [$x1, $x2, $y1, $y2, $orientation] ;
		$x1 = $x - $spaceTextX/2 ; $x2 = $x + $spaceTextX/2 ; $y1 = $y + $thickness + $spaceTextY ; $y2 = $y + $thickness ; $orientation = "centered" ; 
		push @positions, [$x1, $x2, $y1, $y2, $orientation] ;

		my $positionFound = 0 ;
		$tries = 0 ;
		LABA: foreach my $pos (@positions) {
			$tries++ ;
			# print "$lines[0]   $pos->[0], $pos->[1], $pos->[2], $pos->[3], $pos->[4], $numLines\n" ;
			$positionFound = checkAndDrawText ($pos->[0], $pos->[1], $pos->[2], $pos->[3], $pos->[4], $numLines, \@lines, $color, $textSize, $font, $lineDist, $halo) ;
			if ($positionFound == 1) {
				last LABA ;
			}
		}
		if ($positionFound == 0) { $numLabelsOmitted++ ; }
		if ($tries > 1) { $numLabelsMoved++ ; }
	}
}


sub checkAndDrawText {
#
# checks if area available and if so draws text
#
	my ($x1, $x2, $y1, $y2, $orientation, $numLines, $ref, $col, $size, $font, $lineDist, $halo) = @_ ;
	my @lines = @$ref ;

	if (!areaOccupied ($x1, $x2, $y1, $y2)) {

		for (my $i=0; $i<=$#lines; $i++) {
			my @points = ($x1, $y2+($i+1)*($size+$lineDist), $x2, $y2+($i+1)*($size+$lineDist)) ;
			my $pathName = "LabelPath" . $labelPathId ; 
			$labelPathId++ ;
			push @svgOutputDef, svgElementPath ($pathName, @points) ;
			if ($orientation eq "centered") {
				push @svgOutputPathText, svgElementPathTextAdvanced ($col, $size, $font, $lines[$i], $pathName, 0, "middle", 50, $halo) ;
			}
			if ($orientation eq "left") {
				push @svgOutputPathText, svgElementPathTextAdvanced ($col, $size, $font, $lines[$i], $pathName, 0, "start", 0, $halo) ;
			}
			if ($orientation eq "right") {
				push @svgOutputPathText, svgElementPathTextAdvanced ($col, $size, $font, $lines[$i], $pathName, 0, "end", 100, $halo) ;
			}
		}

		occupyArea ($x1, $x2, $y1, $y2) ;
		
		return (1) ;
	}
	else {
		return 0 ;
	}
}

sub getDimensions {
#
# returns dimensions of map
#
	return ($sizeX, $sizeY) ;
}



sub drawAreaOcean {
	my ($col, $ref) = @_ ;
	push @svgOutputAreas, svgElementMultiPolygonFilled ($col, "none", $ref) ;
}

sub sizePNG {
#
# evaluates size of png graphics
#
	my $fileName = shift ;

	my ($x, $y) ;
	my $file ;
	my $result = open ($file, "<", $fileName) ;
	if ($result) {
		my $pic = newFromPng GD::Image($file) ;
		($x, $y) = $pic->getBounds ;
		close ($file) ;
	}
	else {
		($x, $y) = (0, 0) ;
	}
	return ($x, $y) ;
}

sub sizeSVG {
#
# evaluates size of svg graphics
#
	my $fileName = shift ;
	my $file ;
	my ($x, $y) ; undef $x ; undef $y ;

	my $result = open ($file, "<", $fileName) ;
	if ($result) {
		my $line ;
		while ($line = <$file>) {
			my ($x1) = ( $line =~ /^.*width=\"([\d]+)px\"/ ) ; 
			my ($y1) = ( $line =~ /^.*height=\"([\d]+)px\"/ ) ;
			if (!defined $x1) {
				($x1) = ( $line =~ /^\s*width=\"([\d]+)\"/ ) ; 

			} 
			if (!defined $y1) {
				($y1) = ( $line =~ /^\s*height=\"([\d]+)\"/ ) ; 
			} 
			if (defined $x1) { $x = $x1 ; }
			if (defined $y1) { $y = $y1 ; }
		}
		close ($file) ;
	}

	if ( (!defined $x) or (!defined $y) ) { 
		$x = 0 ; $y = 0 ; 
		print "WARNING: size of file $fileName could not be determined.\n" ;
	} 
	return ($x, $y) ;
}

sub scalePoints {
	my $a = shift ;
	# my $b = $a ;
	my $b = $a / $baseDpi * $dpi ;

	return (int ($b*10)) / 10 ;
}


sub scaleBase {
#
# function scales sizes given in 300dpi to base dpi given in rules so texts in legend, ruler etc. will appear in same size
#
	my $a = shift ;
	my $b = $a / 300 * $baseDpi ;
	return $b ;
}

#-----------------------------------------------------------------------------

sub simplifyPoints {
	my $ref = shift ;
	my @points = @$ref ;
	my @newPoints ;
	my $maxIndex = $#points ;

	if (scalar @points > 4) {
		# push first
		push @newPoints, $points[0], $points[1] ;

		# push other
		for (my $i=2; $i <= $maxIndex; $i+=2) {
			$simplifyTotal++ ;
			if ( ($points[$i]==$points[$i-2]) and ($points[$i+1]==$points[$i-1]) ) {
				# same
				$simplified++ ;
			}
			else {
				push @newPoints, $points[$i], $points[$i+1] ;
			}
		}
		return (\@newPoints) ;
	}
	else {
		return ($ref) ;
	}

}

sub simplifiedPercent {
	return ( int ($simplified / $simplifyTotal * 100) ) ;
}

sub drawPageNumber {
	my ($size, $col, $num) = @_ ;
	my $x = $sizeX - scalePoints (scaleBase (80)) ;
	my $y = $sizeY - scalePoints (scaleBase (80)) ;
	drawTextPixGrid ($x, $y, $num, $col, scalePoints ( scaleBase ($size) ) ) ;
}

sub drawPageNumberLeft {
	my ($size, $col, $num) = @_ ;
	my $x = scalePoints (scaleBase (80)) ;
	my $y = $sizeY / 2 ;
	drawTextPixGrid ($x, $y, $num, $col, scalePoints ( scaleBase ($size) ) ) ;

}

sub drawPageNumberBottom {
	my ($size, $col, $num) = @_ ;
	my $x = $sizeX / 2 ;
	my $y = $sizeY - scalePoints (scaleBase (80)) ;
	drawTextPixGrid ($x, $y, $num, $col, scalePoints ( scaleBase ($size) ) ) ;

}

sub drawPageNumberRight {
	my ($size, $col, $num) = @_ ;
	my $x = $sizeX - scalePoints (scaleBase (80)) ;
	my $y = $sizeY / 2 ;
	drawTextPixGrid ($x, $y, $num, $col, scalePoints ( scaleBase ($size) ) ) ;

}

sub drawPageNumberTop {
	my ($size, $col, $num) = @_ ;
	my $x = $sizeX / 2 ;
	my $y = scalePoints (scaleBase (80)) ;
	drawTextPixGrid ($x, $y, $num, $col, scalePoints ( scaleBase ($size) ) ) ;

}


sub createShield {
	my ($name, $targetSize) = @_ ;
	my @a = split /:/, $name ;
	my $shieldFileName = $a[1] ;
	my $shieldText = $a[2] ;

	if (! defined $createdShields{$name}) {
		open (my $file, "<", $shieldFileName) or die ("ERROR: shield definition $shieldFileName not found.\n") ;
		my @defText = <$file> ;
		close ($file) ;

		# get size
		# calc scaling
		my $sizeX = 0 ;
		my $sizeY = 0 ;
		foreach my $line (@defText) {
			if (grep /<svg/, $line) {
				($sizeY) = ( $line =~ /height=\"(\d+)px\"/ ) ;
				($sizeX) = ( $line =~ /width=\"(\d+)px\"/ ) ;
				if ( (!defined $sizeX) or (!defined $sizeY) ) {
					die "ERROR: size of shield in $shieldFileName could not be determined.\n" ;
				}
			}
		}
		if ( ($sizeX == 0) or ($sizeY == 0) ) {
			die "ERROR: initial size of shield $shieldFileName could not be determined.\n" ;
		}

		my $scaleFactor = $targetSize / $sizeY ;
		# print "factor: $scaleFactor\n" ;

		$shieldXSize{ $name } = int ($sizeX * $scaleFactor) ;
		$shieldYSize{ $name } = int ($sizeY * $scaleFactor) ;

		$shieldPathId++ ;
		my $shieldPathName = "ShieldPath" . $shieldPathId ;
		my $shieldGroupName = "ShieldGroup" . $shieldPathId ;

		foreach my $line (@defText) {
			$line =~ s/REPLACEID/$shieldGroupName/ ;
			$line =~ s/REPLACESCALE/$scaleFactor/g ;
			$line =~ s/REPLACEPATH/$shieldPathName/ ;
			$line =~ s/REPLACELABEL/$shieldText/ ;
		}

		foreach my $line (@defText) {
			push @svgOutputDef, $line ;
			# print "DEF: $line" ;
		}
		# print "\n" ; 

		$createdShields{$name} = $shieldGroupName ;
	}
}



sub getPointOfWay {
	#
	# returns point of way at distance/position
	#

	my ($ref, $position) = @_ ;
	my @points = @$ref ;

	my @double = () ;
	while (scalar @points > 0) {
		my $x = shift @points ;
		my $y = shift @points ;
		push @double, [$x, $y] ;
	}

	my $i = 0 ; my $actLen = 0 ;
	while ($actLen < $position) {
		$actLen += sqrt ( ($double[$i]->[0]-$double[$i+1]->[0])**2 + ($double[$i]->[1]-$double[$i+1]->[1])**2 ) ;
		$i++ ;
	}

	my $x = int (($double[$i]->[0] +  $double[$i-1]->[0]) / 2) ;
	my $y = int (($double[$i]->[1] +  $double[$i-1]->[1]) / 2) ;

	# print "POW: $x, $y\n" ;

	return ($x, $y) ;
}






1 ;


