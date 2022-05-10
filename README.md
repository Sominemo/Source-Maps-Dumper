# Source Maps Dumper

A simple CLI script to find source maps in a HAR dump and download them.

## Use
```bash
./source_maps_dumper path/to/file.har /dest --save-all --ignore-errors
```

1. Positional parameter: path to HAR dump.
2. Positional parameter: destination folder. Will be created, if doesn't exist.
- `--save-all`: Extract all files, even if they don't have source maps.
- `--ignore-errors`: Download source maps even if response code is not `200 OK`.

### To run from `.dart` file:
- Clone this repo
- `dart run source_maps_dumper <args>`

Or you can get a Windows executable from Releases page.

### Create a HAR dump in Chrome
Chrome DevTools > Network Tab > "Export HAR..." button
![Export UI](https://user-images.githubusercontent.com/19842935/167517363-11d6240d-a875-41c0-bb4f-9e65f1ef87b8.png)
