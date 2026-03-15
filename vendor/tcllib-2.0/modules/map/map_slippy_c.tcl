## -*- tcl -*-
# ### ### ### ######### ######### #########
##
## C implementation for map::slippy
##
## See
##	http://wiki.openstreetmap.org/wiki/Slippy_map_tilenames#Pseudo-Code
##
## for the coordinate conversions and other information.

# ### ### ### ######### ######### #########
## Requisites

package require critcl 3.1.18.2	;# REQUIRED: `[]type` support.
# TODO:                3.2

critcl::license {Andreas Kupries} {BSD licensed.}

#package require critcl::cutil
#critcl::cutil::tracer on
#critcl::config trace
#critcl::debug symbols
#critcl::debug memory

# ### ### ### ######### ######### #########
## API - Helper setup

critcl::ccode {
    #include <math.h>
    #include <stdlib.h>
    #include <string.h>	/* memset */

    #ifndef M_PI
    #define M_PI (3.141592653589793238462643)
    #endif
    #define DEGTORAD     (M_PI/180.)	/* (2pi)/360 */
    #define RADTODEG     (180./M_PI)	/* 360/(2pi) */
    #define OURTILESIZE  (256)
    #define OURTILESIZED ((double) OURTILESIZE)
    #define TILES(z)     (1 << (z))
    #define MIN(a,b)     (((a) < (b)) ? (a) : (b))
    #define MAX(a,b)     (((a) > (b)) ? (a) : (b))

    #define OP Tcl_ObjPrintf
    #define BAD(f, ...) { if (msgv.o != 0) Tcl_ObjSetVar2 (interp, msgv.o, 0, OP (f, __VA_ARGS__), 0); return 0; }
}

# ### ### ### ######### ######### #########
## Custom argument and result processing

critcl::source c/geo.tcl
critcl::source c/geobox.tcl
critcl::source c/point.tcl
critcl::source c/pointbox.tcl
critcl::source c/wxh.tcl
critcl::source c/common.tcl

# ### ### ### ######### ######### #########
## Implementation

critcl::cproc ::map::slippy::critcl_geo_valid_list {
    []geo gs
} bool {
    unsigned int k;
    for (k = 0; k < gs.c; k++) {
	if (!((gs.v[k].lat >=  -90) && (gs.v[k].lat <=  90) &&
	      (gs.v[k].lon >= -180) && (gs.v[k].lon <= 180))) {
	    return 0;
	}
    }
    return 1;
}

critcl::cproc ::map::slippy::critcl_geo_box_valid_list {
    []geobox gs
} bool {
    unsigned int k;
    for (k = 0; k < gs.c; k++) {
	if (!((gs.v[k].lat0 >=  -90) && (gs.v[k].lat0 <=  90) &&
	      (gs.v[k].lon0 >= -180) && (gs.v[k].lon0 <= 180) &&
	      (gs.v[k].lat1 >=  -90) && (gs.v[k].lat1 <=  90) &&
	      (gs.v[k].lon1 >= -180) && (gs.v[k].lon1 <= 180))) {
	    return 0;
	}
    }
    return 1;
}

critcl::cproc ::map::slippy::critcl_geo_valid {
    geo g
} bool {
    return
	(g.lat >=  -90) && (g.lat <=  90) &&
	(g.lon >= -180) && (g.lon <= 180);
}

critcl::cproc ::map::slippy::critcl_geo_box_valid {
    geobox gbox
} bool {
    return
	(gbox.lat0 >=  -90) && (gbox.lat0 <=  90) &&
	(gbox.lon0 >= -180) && (gbox.lon0 <= 180) &&
	(gbox.lat1 >=  -90) && (gbox.lat1 <=  90) &&
	(gbox.lon1 >= -180) && (gbox.lon1 <= 180);
}

critcl::cproc ::map::slippy::critcl_valid_latitude {
    double x
} bool {
    return (x >= -90) && (x <= 90);
}

critcl::cproc ::map::slippy::critcl_valid_longitude {
    double x
} bool {
    return (x >= -180) && (x <= 180);
}

critcl::cproc ::map::slippy::critcl_limit6 {
    Tcl_Interp* interp
    double      x
} object0 {
    return delimit (x, 1000000);
}

critcl::cproc ::map::slippy::critcl_limit3 {
    Tcl_Interp* interp
    double      x
} object0 {
    return delimit (x, 1000);
}

critcl::cproc ::map::slippy::critcl_limit2 {
    Tcl_Interp* interp
    double      x
} object0 {
    return delimit (x, 100);
}

critcl::cproc ::map::slippy::critcl_length {
    int level
} int {
    return OURTILESIZE * TILES (level);
}

critcl::cproc ::map::slippy::critcl_tiles {
    int level
} int {
    return TILES (level);
}

critcl::cconst ::map::slippy::critcl_tile_size int OURTILESIZE

critcl::cproc ::map::slippy::critcl_tile_valid {
    Tcl_Interp* interp
    int         zoom
    int         row
    int         col
    int         levels
    pstring    {msgv ms_pstring_empty()}
} boolean {
    if ((zoom < 0) || (zoom >= levels)) {
	BAD ("Bad zoom level '%d' (max: %d)", zoom, levels);
    }

    int tiles = TILES (zoom);

    if ((row < 0) || (row >= tiles) ||
	(col < 0) || (col >= tiles)) {
	BAD ("Bad cell '%d %d' (max: %d)", row, col, tiles);
    }

    return 1;
}

critcl::cproc ::map::slippy::critcl_geo_box_limit {
    Tcl_Interp* interp
    geobox      gbox
} object0 {
    Tcl_Obj* cl[4];
    cl [0] = delimit (gbox.lat0, 1000000);
    cl [1] = delimit (gbox.lon0, 1000000);
    cl [2] = delimit (gbox.lat1, 1000000);
    cl [3] = delimit (gbox.lon1, 1000000);
    return Tcl_NewListObj(4, cl); /* OK tcl9 */
}

critcl::cproc ::map::slippy::critcl_geo_box_inside {
    Tcl_Interp* interp
    geobox      gbox
    geo         g
} bool {
    return ((g.lat >= gbox.lat0) && (g.lat <= gbox.lat1) &&
	    (g.lon >= gbox.lon0) && (g.lon <= gbox.lon1));
}

critcl::cproc ::map::slippy::critcl_geo_box_center {
    Tcl_Interp* interp
    geobox      gbox
} geo {
    geo out = {
	.lat = (gbox.lat0 + gbox.lat1) / 2.,
	.lon = (gbox.lon0 + gbox.lon1) / 2.
    };

    return out;
}

critcl::cproc ::map::slippy::critcl_geo_box_dimensions {
    Tcl_Interp* interp
    geobox      gbox
} wxh {
    wxh out = {
	.w = (gbox.lon1 - gbox.lon0),
	.h = (gbox.lat1 - gbox.lat0)
    };

    return out;
}

critcl::cproc ::map::slippy::critcl_geo_box_2point {
    int    zoom
    geobox gbox
} pointbox {
    geo gmin = {
	.lat = gbox.lat0,
	.lon = gbox.lon0
    };
    geo gmax = {
	.lat = gbox.lat1,
	.lon = gbox.lon1
    };

    point pmin, pmax;

    geo_2point (zoom, &gmin, &pmin);
    geo_2point (zoom, &gmax, &pmax);

    pointbox out = {
	.x0 = MIN(pmin.x,pmax.x),
	.y0 = MIN(pmin.y,pmax.y),
	.x1 = MAX(pmin.x,pmax.x),
	.y1 = MAX(pmin.y,pmax.y)
    };

    return out;
}

critcl::cproc ::map::slippy::critcl_geo_box_corners {
    Tcl_Interp* interp
    geobox      gbox
} object0 {
    geo g[4] = {{
	.lat = gbox.lat0,
	.lon = gbox.lon0
    }, {
	.lat = gbox.lat0,
	.lon = gbox.lon1
    }, {
	.lat = gbox.lat1,
	.lon = gbox.lon0
    }, {
	.lat = gbox.lat1,
	.lon = gbox.lon1
    }};

    return geo_box_list (0, interp, 4, g);
}

critcl::cproc ::map::slippy::critcl_geo_box_diameter {
    Tcl_Interp* interp
    geobox      gbox
} double {
    geo g[2] = {{
	.lat = gbox.lat0,
	.lon = gbox.lon0
    }, {
	.lat = gbox.lat1,
	.lon = gbox.lon1
    }};

    return geo_distance_list (0, 2, g);
}

critcl::cproc ::map::slippy::critcl_geo_box_opposites {
    Tcl_Interp* interp
    geobox      gbox
} object0 {
    geo g[2] = {{
	.lat = gbox.lat0,
	.lon = gbox.lon0
    }, {
	.lat = gbox.lat1,
	.lon = gbox.lon1
    }};

    return geo_box_list (0, interp, 2, g);
}

critcl::cproc ::map::slippy::critcl_geo_box_perimeter {
    Tcl_Interp* interp
    geobox      gbox
} double {
    geo g[4] = {{
	.lat = gbox.lat0,
	.lon = gbox.lon0
    }, {
	.lat = gbox.lat0,
	.lon = gbox.lon1
    }, {
	.lat = gbox.lat1,
	.lon = gbox.lon0
    }, {
	.lat = gbox.lat1,
	.lon = gbox.lon1
    }};

    return geo_distance_list (1, 4, g);
}

critcl::cproc ::map::slippy::critcl_geo_box_fit {
    geobox gbox
    wxh    canvdim
    int    zmax
    int    {zmin 0}
} int {
    double canvw = canvdim.w;
    double canvh = canvdim.h;

    geo gmin = {
	.lat  = gbox.lat0,
	.lon  = gbox.lon0
    };
    geo gmax = {
	.lat  = gbox.lat1,
	.lon  = gbox.lon1
    };

    point pmin, pmax;

    // NOTE we assume ourtilesize == [map::slippy length 0].
    // Further, we assume that each zoom step "grows" the linear resolution by a factor 2
    // (that's the log(2) down there)

    canvw = fabs (canvw);
    canvh = fabs (canvh);

    int z = (int) (log(fmin(
			(canvh/OURTILESIZED) / (fabs(gbox.lat1 - gbox.lat0)/180.),
			(canvw/OURTILESIZED) / (fabs(gbox.lon1 - gbox.lon0)/360.)))
		/ log(2));
    //fprintf(stdout, "z'initial:%d\n", z);fflush(stdout);
    // clamp
    z = ((z < zmin) ? zmin : ((z > zmax) ? zmax : z));
    //fprintf(stdout, "z'clamp:%d\n", z);fflush(stdout);

    // Now zoom is an approximation, since the scale factor isn't uniform across the map
    // (the vertical dimension depends on latitude). So we have to refine iteratively
    // (It is expected to take just one step):

    int z1, z0, hasz1, hasz0;

    hasz0 = hasz1 = 0;

    while (1) {
	//fprintf(stdout, "try zoom %d\n", z);fflush(stdout);
	// Now we can run "uphill",   getting z0 = z - 1
	// and            "downhill", getting z1 = z + 1
	// (borders from the last iteration)

	geo_2point (z, &gmin, &pmin);
	geo_2point (z, &gmax, &pmax);

	double w = fabs(pmax.x - pmin.x);
	double h = fabs(pmax.y - pmin.y);

	//fprintf(stdout, "dimensions|w|%f|%f|h|%f|%f\n", w, canvw, h, canvh);fflush(stdout);

	if ((w > canvw) || (h > canvh)) {
	    //fprintf(stdout, "to big: shrink z0?%d\n", hasz0);fflush(stdout);
	    // too big: shrink
	    if (hasz0) break; // but not if we came from below
	    if (z <= zmin) break; // can't be < zmin
	    z1 = z ; hasz1 = 1;
	    z --;
	} else {
	    //fprintf(stdout, "fits: grow z1?%d\n", hasz1);fflush(stdout);
	    // fits: grow
	    if (hasz1) break; // but not if we came from above
	    if (z >= zmax) {
		//fprintf(stdout, "fits: at max!\n");fflush(stdout);
		break; // can't be > zmax
	    }
	    z0 = z ; hasz0 = 1;
	    z ++;
	}
    }

    if (hasz0) { z = z0; }
    //fprintf(stdout, "z'final:%d\n", z);fflush(stdout);
    return z;
}

critcl::cproc ::map::slippy::critcl_geo_limit {
    Tcl_Interp* interp
    geo         g
} object0 {
    Tcl_Obj* cl[4];
    cl [0] = delimit (g.lat, 1000000);
    cl [1] = delimit (g.lon, 1000000);
    return Tcl_NewListObj(2, cl); /* OK tcl9 */
}

critcl::cproc ::map::slippy::critcl_geo_distance {
    geo geoa
    geo geob
} double {
    // lat, lon are in degrees - convert all to radians

    double lata = DEGTORAD * geoa.lat;
    double lona = DEGTORAD * geoa.lon;
    double latb = DEGTORAD * geob.lat;
    double lonb = DEGTORAD * geob.lon;

    double d = geo_distance (lata, lona, latb, lonb);

    // Convert to meters and return
    double meters = 6371009 * d;
    return meters;
}

critcl::cproc ::map::slippy::critcl_geo_distance_args {
    bool closed
    geo  args
} double {
    return geo_distance_list (closed, args.c, args.v);
}

critcl::cproc ::map::slippy::critcl_geo_distance_list {
    bool  closed
    []geo geos
} double {
    return geo_distance_list (closed, geos.c, geos.v);
}

critcl::cproc ::map::slippy::critcl_geo_bbox {
    geo args
} geobox {
    return geo_bbox (args.c, args.v);
}

critcl::cproc ::map::slippy::critcl_geo_bbox_list {
    []geo geos
} geobox {
    return geo_bbox (geos.c, geos.v);
}

critcl::cproc ::map::slippy::critcl_geo_center {
    geo args
} geo {
    return geo_center (args.c, args.v);
}

critcl::cproc ::map::slippy::critcl_geo_center_list {
    []geo geos
} geo {
    return geo_center (geos.c, geos.v);
}

critcl::cproc ::map::slippy::critcl_geo_diameter {
    geo args
} double {
    return geo_diameter (args.c, args.v);
}

critcl::cproc ::map::slippy::critcl_geo_diameter_list {
    []geo geos
} double {
    return geo_diameter (geos.c, geos.v);
}

critcl::cproc ::map::slippy::critcl_geo_2point {
    int zoom
    geo g
} point {
    point out;

    geo_2point (zoom, &g, &out);

    return out;
}

critcl::cproc ::map::slippy::critcl_geo_2point_args {
    Tcl_Interp* interp
    int         zoom
    geo         args
} object0 {
    if (args.c == 0) {
	/* Pass the input, no need for transient helper memory */
	return Tcl_NewListObj (0,0); /* OK tcl9 */
    }

    return point_box_list (1, interp, args.c, geos_2points (zoom, args.c, args.v));
}

critcl::cproc ::map::slippy::critcl_geo_2point_list {
    Tcl_Interp* interp
    int         zoom
    []geo       geos
} object0 {
    if (geos.c == 0) {
	/* Pass the input, no need for transient helper memory */
	return Tcl_NewListObj (0,0); /* OK tcl9 */
    }

    return point_box_list (1, interp, geos.c, geos_2points (zoom, geos.c, geos.v));
}

critcl::cproc ::map::slippy::critcl_point_box_inside {
    Tcl_Interp* interp
    pointbox    pbox
    point       p
} bool {
    return ((p.x >= pbox.x0) && (p.x <= pbox.x1) &&
	    (p.y >= pbox.y0) && (p.y <= pbox.y1));
}

critcl::cproc ::map::slippy::critcl_point_box_center {
    Tcl_Interp* interp
    pointbox    pbox
} point {
    point out = {
	.x = (pbox.x0 + pbox.x1) / 2.,
	.y = (pbox.y0 + pbox.y1) / 2.
    };

    return out;
}

critcl::cproc ::map::slippy::critcl_point_box_dimensions {
    Tcl_Interp* interp
    pointbox      pbox
} wxh {
    wxh out = {
	.w = (pbox.x1 - pbox.x0),
	.h = (pbox.y1 - pbox.y0)
    };

    return out;
}

critcl::cproc ::map::slippy::critcl_point_box_2geo {
    int      zoom
    pointbox pbox
} geobox {
    point pmin = {
	.y = pbox.y0,
	.x = pbox.x0
    };
    point pmax = {
	.y = pbox.y1,
	.x = pbox.x1
    };

    geo gmin, gmax;

    point_2geo (zoom, &pmin, &gmin);
    point_2geo (zoom, &pmax, &gmax);

    geobox out = {
	.lat0 = MIN(gmin.lat,gmax.lat),
	.lon0 = MIN(gmin.lon,gmax.lon),
	.lat1 = MAX(gmin.lat,gmax.lat),
	.lon1 = MAX(gmin.lon,gmax.lon)
    };

    return out;
}

critcl::cproc ::map::slippy::critcl_point_box_corners {
    Tcl_Interp* interp
    pointbox    pbox
} object0 {
    point p[4] = {{
	.x = pbox.x0,
	.y = pbox.y0
    }, {
	.x = pbox.x0,
	.y = pbox.y1
    }, {
	.x = pbox.x1,
	.y = pbox.y0
    }, {
	.x = pbox.x1,
	.y = pbox.y1
    }};

    return point_box_list (0, interp, 4, p);
}

critcl::cproc ::map::slippy::critcl_point_box_diameter {
    Tcl_Interp* interp
    pointbox    pbox
} double {
    point p[2] = {{
	.x = pbox.x0,
	.y = pbox.y0
    }, {
	.x = pbox.x1,
	.y = pbox.y1
    }};

    return point_distance_list (0, 2, p);
}

critcl::cproc ::map::slippy::critcl_point_box_opposites {
    Tcl_Interp* interp
    pointbox    pbox
} object0 {
    point p[2] = {{
	.x = pbox.x0,
	.y = pbox.y0
    }, {
	.x = pbox.x1,
	.y = pbox.y1
    }};

    return point_box_list (0, interp, 2, p);
}

critcl::cproc ::map::slippy::critcl_point_box_perimeter {
    Tcl_Interp* interp
    pointbox    pbox
} double {
    point p[4] = {{
	.x = pbox.x0,
	.y = pbox.y0
    }, {
	.x = pbox.x0,
	.y = pbox.y1
    }, {
	.x = pbox.x1,
	.y = pbox.y0
    }, {
	.x = pbox.x1,
	.y = pbox.y1
    }};

    return point_distance_list (1, 4, p);
}

critcl::cproc ::map::slippy::critcl_point_distance {
    point pointa
    point pointb
} double {
    return point_distance (&pointa, &pointb);
}

critcl::cproc ::map::slippy::critcl_point_distance_args {
    bool  closed
    point args
} double {
    return point_distance_list (closed, args.c, args.v);
}

critcl::cproc ::map::slippy::critcl_point_distance_list {
    bool    closed
    []point points
} double {
    return point_distance_list (closed, points.c, points.v);
}

critcl::cproc ::map::slippy::critcl_point_bbox {
    point args
} pointbox {
    return point_bbox (args.c, args.v);
}

critcl::cproc ::map::slippy::critcl_point_bbox_list {
    []point points
} pointbox {
    return point_bbox (points.c, points.v);
}

critcl::cproc ::map::slippy::critcl_point_center {
    point args
} point {
    return point_center (args.c, args.v);
}

critcl::cproc ::map::slippy::critcl_point_center_list {
    []point points
} point {
    return point_center (points.c, points.v);
}

critcl::cproc ::map::slippy::critcl_point_diameter {
    point args
} double {
    return point_diameter (args.c, args.v);
}

critcl::cproc ::map::slippy::critcl_point_diameter_list {
    []point points
} double {
    return point_diameter (points.c, points.v);
}

critcl::cproc ::map::slippy::critcl_point_2geo {
    int   zoom
    point p
} geo {
    geo out;

    point_2geo (zoom, &p, &out);

    return out;
}

critcl::cproc ::map::slippy::critcl_point_2geo_args {
    Tcl_Interp* interp
    int         zoom
    point       args
} object0 {
    if (args.c == 0) {
	/* Pass the input, no need for transient helper memory */
	return Tcl_NewListObj (0,0); /* OK tcl9 */
    }

    return geo_box_list (1, interp, args.c, points_2geos (zoom, args.c, args.v));
}

critcl::cproc ::map::slippy::critcl_point_2geo_list {
    Tcl_Interp* interp
    int         zoom
    []point     points
} object0 {
    if (points.c == 0) {
	/* Pass the input, no need for transient helper memory */
	return Tcl_NewListObj (0,0); /* OK tcl9 */
    }

    return geo_box_list (1, interp, points.c, points_2geos (zoom, points.c, points.v));
}

critcl::cproc ::map::slippy::critcl_point_simplify_radial {
    Tcl_Interp* interp
    double      threshold
    bool        closed
    []point     points
} object0 {
    unsigned int k;
    if (points.c < 2) {
	/* Pass the input, no need for transient helper memory */
	return points.o;
    }

    point* res = (point*) ckalloc (points.c * sizeof(point));

    unsigned int anchor = 0;
    unsigned int into   = 0;

    res[into].y = points.v[anchor].y;
    res[into].x = points.v[anchor].x;
    into ++;

    for (k = 1; k < points.c; k++) {
	double d = hypot (points.v[k].x - points.v[anchor].x,
			  points.v[k].y - points.v[anchor].y);
	if (d < threshold) continue;

	anchor = k;

	res[into].y = points.v[anchor].y;
	res[into].x = points.v[anchor].x;
	into ++;
    }

    if (closed && (into > 1)) {
	// For an actual loop, check last against first, remove last if necessary
	double d = hypot (res[0].x - res[into-1].x,
			  res[0].y - res[into-1].y);
	if (d < threshold) {
	    into --;
	    // into > 0
	}

	if (into == 2) {
	    // Loop degenerated into line, reduce to singularity using line center
	    res[0].x = (res[0].x + res[1].x)/2.;
	    res[0].y = (res[0].y + res[1].y)/2.;
	    into = 1;
	}
    }

    // Note: into >= 1, i.e. at least one point is present.

    return point_box_list (1, interp, into, res);
}

critcl::cproc ::map::slippy::critcl_point_simplify_rdp {
    Tcl_Interp* interp
    []point     points
} object0 {
    if (points.c < 3) {
	/* Pass the input, no need for transient helper memory */
	return points.o;
    }

    /* Enough data present to run the full algorithm */

    char*     keep = (char*) ckalloc (points.c * sizeof(char));
    memset   (keep, 0,                points.c * sizeof(char));

    rdp_core (keep, points.v, 0, points.c-1);

    /* Compress the input array down to the kept points */

    unsigned int into = 0;
    unsigned int i;
    for (i=0; i < points.c; i++) {
        if (!keep[i]) continue;
	points.v[into] = points.v[i];
	into++;
    }
    ckfree (keep);

    if (!into) {
	return Tcl_NewListObj (0,0); /* OK tcl9 */
    }

    return point_box_list (0, interp, into, points.v);
}

# ### ### ### ######### ######### #########
## Ready
return
