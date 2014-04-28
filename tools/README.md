This directory contains some example file.

* `example.txt`, contains 3 example lines that should become 3 tasks.
* `example.json` is the result produced from `example.txt` using the
following command:
```
python make_json.py -o example.json example.txt "This is a test" 
```

You can pretty-print the result json with this command:
```
cat example.json | python -mjson.tool
```

You can also use the great command-line tool 
`[jq](http://stedolan.github.io/jq/)`
to manipulate the resulting json.

The following command gives the lenght of the result array stored in
`example.json`
```
jq '. | length' example.json 
```