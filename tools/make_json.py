#from geojson import *
import sys

with open("../tasks/valle-aosta_aree.txt", "r") as f:
  	for line in f:
    		line.rstrip()
		chunk = line.split(' ')
		print '{'
		print ' "geometries" : {'
		print '    "type": "FeatureCollection",'
		print '    "features": ['
		print '      { "type": "Feature",'
		print '        "geometry":'
		print '        { "type": "LineString",'
		sys.stdout.write( '          "coordinates": [')
		chunk[1].rstrip()
		sys.stdout.write(chunk[1])
		sys.stdout.write(']')
		print
		print '        },'
		sys.stdout.write( ' "properties": {"osmid": ')
		id = chunk[0].split('_')
		sys.stdout.write(id[1])
		sys.stdout.write('}')
		print
		print '      }'
		print '    ]'
		print '  }'
		print '}'
f.close()


# OUTPUT EXAMPLE
#
#{ 
#  "instruction" : "This is a hard task!",
#  "geometries" : {
#    "type": "FeatureCollection",
#    "features": [
#      { "type": "Feature",
#        "geometry": 
#        { "type": "LineString", 
#          "coordinates": [[-88.72199, 30.39396], [-88.72135, 30.39395], [-88.72125, 30.3939]]
#        },
#        "properties": {"osmid": 23456}
#      }
#    ]
#  }
#}  
