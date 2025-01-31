
The commands of this package operate in two distinct coordinate systems, geographical locations, and
points. The former represents coordinates for locations on Earth, while the latter is for use on Tk
[term canvas] widgets.

[subsection Geographic]

Geographical locations (short: [term geo]) are represented by a pair of [term Latitude] and
[term Longitude] values, each of which is measured in degrees, as they are essentially angles.

[para] The [const Zero] longitude is the [term {Greenwich meridian}], with positive values going
[term east], and negative values going [term west], for a total range of +/- 180 degrees. Note that
+180 and -180 longitude are the same [term meridian], opposite to Greenwich.

[para] The [const zero] latitude is the [term Equator], with positive values going [term north] and
negative values going [term south]. While the true range is +/- 90 degrees the projection used by
the package requires us to cap the range at roughly +/- [const 85.05112877983284] degrees. This
means that the North and South poles are not representable and not part of any map.

[para] A geographical location is represented by a list containing two values, the latitude, and
longitude of the location, in this order.

[para] A geographical bounding box is represented by a list containing four values, the minimal
latitude and longitude of the box, and the maximal latitude and longitude of the box, in this order.

[para] Geographical locations and boxes can be converted to points and their boxes by means of an
additional parameter, the [term zoom] level. This parameter indicates the size of the map in the
canvas the coordinates are to be projected into.

[subsection Points]

Points (short: [term point]) are represented by a pair of [term x] and [term y] values, each of
which is measured in pixels. They reference a location in a Tk [term canvas] widget.

As a map can be shown at different degrees of magnification, the exact pixel coordinates for a
geographical location depend on this [term zoom] level.

[para] For the following explanation to make sense it should be noted that a map shown in a Tk
[term canvas] widget is split into equal-sized quadratic [term tiles].

[para] Point coordinates are tile coordinates scaled by the size of these tiles. This package uses
tiles of size [const 256], which is the standard size used by many online servers providing map
tiles of some kind or other.

[para] A point is represented by a list containing the x- and y-coordinates of the lcoation, in this
in this order.

[para] A point bounding box is represented by a list containing four values, the minimal x and y of
the box, and the maximal x and y of the box, in this order.

[para] Point locations and boxes can be converted to geographical locations and their boxes by means
of an additional parameter, the [term zoom] level. This parameter indicates the size of the map in
the canvas the coordinates are projected from.

[para] Tile coordinates appear only in one place of the API, in the signature of command
[cmd {map slippy tile valid}]. Everything else uses Point coordinates.

[para] Using tile coordinates in the following however makes the structure of the map at the various
[term zoom] levels (maginification factors) easier to explain.

[para] Generally the integer part of the tile coordinates represent the row and column number of a
tile of the map, wheras the fractional parts signal how far inside that tile the location in
question is, with pure integer coordinates (no fractional part) representing the upper left corner
of a tile.

[para] The zero point of the map is at the upper left corner, regardless of zoom level, with larger
coordinates going right (east) and down (south), and smaller coordinates going left (west) and up
(north). Again regardless of zoom level.

[para] Negative coordinates are not allowed.

[para] At zoom level [const 0] the entire map is represented by a single tile, putting the
geographic zero at 1/2, 1/2 in terms of tile coordinates, and the range of tile coordinates as
[lb]0...1[rb].

[para] When going from zoom level [var N] to the next deeper (magnified) level ([var N]+1) each tile
of level [var N] is split into its four quadrants, which then are the tiles of level [var N]+1.

[para] This means that at zoom level [var N] the map is sliced (horizontally and vertically) into
[const 2^N] rows and columns, for a total of [const 4^N] tiles, with the tile coordinates ranging from
[const 0] to [const 2^N+1].
