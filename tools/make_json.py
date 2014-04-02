#!/usr/bin/env python

import geojson
import ast
import json


def get_data_from_line(line):
    chunks = line.strip('\n').split(' ')
    osm_id = int(chunks[0].split('_')[1])
    coord_string = '[{}]'.format(chunks[1].strip('\n'))
    coords = ast.literal_eval(coord_string)
    return osm_id, coords


def make_json(input_file, instruction, output_file):
    tasks = []
    with open(input_file, 'r') as infile:
        for line in infile:
            task = {}
            task['instruction'] = instruction
            task['geometries'] = {
                'type': 'FeatureCollection',
                'features': []
            }

            osm_id, coords = get_data_from_line(line)
            geometry = geojson.LineString(coords)

            feature = {
                'type': 'Feature',
                'geometry': geometry,
                'properties': {"osmid": osm_id}
            }

            task['geometries']['features'].append(feature)
            tasks.append(task)

    with open(output_file, 'w+') as outfile:
        json.dump(tasks, outfile)

if __name__ == '__main__':
    import argparse

    description = 'Produce un file JSON a partire dal txt degli errori.'
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument('input_file', help='File txt di input')
    parser.add_argument('instruction', help='istruzioni del task')
    parser.add_argument('-o', dest='output_file',
                        help='File json di output',
                        default='output.json'
                        )

    args = parser.parse_args()

    # OUTPUT EXAMPLE
    #
    # This can be obtained with the two following commands:
    #
    # python make_json.py test.txt "This is a hard task"
    # cat output.json | python -mjson.tool
    #
    #{
    #  "instruction" : "This is a hard task",
    #  "geometries" : {
    #    "type": "FeatureCollection",
    #    "features": [
    #      { "type": "Feature",
    #        "geometry":
    #        { "type": "LineString",
    #          "coordinates": [[-88.72199, 30.39396], [-88.72135, 30.39395],
    #                          [-88.72125, 30.3939]]
    #        },
    #        "properties": {"osmid": 23456}
    #      }
    #    ]
    #  }
    #}

    make_json(args.input_file, args.instruction, args.output_file)
