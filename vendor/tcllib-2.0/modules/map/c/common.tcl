## -*- tcl -*-
# ### ### ### ######### ######### #########
## Supporting functions

# Force various C types to be declared for use by helper functions and code.
# - critcl_pstring

critcl::cproc ::map::slippy::DOOM {pstring dummy} void {}
critcl::ccode {
    static critcl_pstring ms_pstring_empty() { critcl_pstring x = {0,0,0} ; return x; }

    // you initialize a struct variable as shown above. You cannot assign to it in the same manner
    // after initialization. You need a value of the proper type. The helper produces such a thing
    // for us. We use it as the default value for the optional `msgv` argument (a varname)
}

# https://en.wikipedia.org/wiki/Haversine_formula
# https://wiki.tcl-lang.org/page/geodesy
# https://en.wikipedia.org/wiki/Geographical_distance	| For radius used in angle
# https://en.wikipedia.org/wiki/Earth_radius		| to meter conversion
##
# Go https://en.wikipedia.org/wiki/N-vector ?

critcl::ccode {
    static Tcl_Obj* delimit(double x, double factor) {
	if (x == (double)(int)x) {
	    return Tcl_NewIntObj ((int) x); /* OK tcl9 */
	}

	x = round(x * factor)/factor;

	if (x == (double)(int)x) {
	    return Tcl_NewIntObj ((int) x); /* OK tcl9 */
	}
	return Tcl_NewDoubleObj (x);
    }

    static void geo_2point (int zoom, geo* g, point* p) {
	int    tiles  = TILES (zoom);
	double latrad = DEGTORAD * g->lat;
	double row    = (1 - (log(tan(latrad) + 1.0/cos(latrad)) / M_PI)) / 2 * tiles;
	double col    = ((g->lon + 180.0) / 360.0) * tiles;

	p->y = OURTILESIZE * row;
	p->x = OURTILESIZE * col;
    }

    static point* geos_2points (int zoom, int c, geo* geos) {
	point* p = (point*) ckalloc (c * sizeof(point));
	unsigned int k;

	for (k = 0; k < c; k++) geo_2point (zoom, &geos[k], &p[k]);

	return p;
    }

    // - - -- --- ----- -------- -------------

    static void point_2geo (int zoom, point* p, geo* g) {
	double x      = p->x;
	double y      = p->y;

	int    length = OURTILESIZE * TILES (zoom);
	double lat    = RADTODEG * (atan(sinh(M_PI * (1 - 2 * y / length))));
	double lon    = x / length * 360.0 - 180.0;

	g->lat = lat;
	g->lon = lon;
	return;
    }

    static geo* points_2geos (int zoom, int c, point* points) {
	geo* g = (geo*) ckalloc (c * sizeof(geo));
	unsigned int k;

	for (k = 0; k < c; k++) point_2geo (zoom, &points[k], &g[k]);

	return g;
    }

    // - - -- --- ----- -------- -------------

    static double geo_distance (double lata, double lona, double latb, double lonb) {
	double dlat   = latb - lata;
	double dlon   = lonb - lona;
	double hsdlat = sin(dlat/2.);
	double hsdlon = sin(dlon/2.);
	double h      = hsdlat*hsdlat + cos(lata)*cos(latb)*hsdlon*hsdlon;

	// Distance base, clamp to -1..1, then to angle
	if (fabs(h) > 1.0) { h = (h > 0) ? 1 : -1; }

	return 2*asin(sqrt(h));
    }

    static double geo_distance_list (int closed, int c, geo* geos) {
	// lat, lon are in degrees - convert all to radians

	double d = 0;
	double lata = DEGTORAD * geos[0].lat;
	double lona = DEGTORAD * geos[0].lon;
	unsigned int i;

	if (c < 2) {
	    return 0;
	}

	for (i = 1; i < c ; i++) {
	    double latb = DEGTORAD * geos[i].lat;
	    double lonb = DEGTORAD * geos[i].lon;

	    d += geo_distance (lata, lona, latb, lonb);

	    lata = latb;
	    lona = lonb;
	}

	if (closed) {
	    double latb = DEGTORAD * geos[0].lat;
	    double lonb = DEGTORAD * geos[0].lon;

	    d += geo_distance (lata, lona, latb, lonb);
	}

	// Convert to meters and return
	double meters = 6371009 * d;
	return meters;
    }

    static geobox geo_bbox (int c, geo* geos) {
	unsigned int i;

	if (c == 0) {
	    geobox bounding = { 0, 0, 0, 0 };
	    return bounding;
	}

	geobox bounding = {
	    .lat0 = geos[0].lat,
	    .lon0 = geos[0].lon,
	    .lat1 = geos[0].lat,
	    .lon1 = geos[0].lon
	};

	for (i = 1; i < c; i++) {
	    bounding.lat0 = MIN (bounding.lat0, geos[i].lat);
	    bounding.lon0 = MIN (bounding.lon0, geos[i].lon);
	    bounding.lat1 = MAX (bounding.lat1, geos[i].lat);
	    bounding.lon1 = MAX (bounding.lon1, geos[i].lon);
	}

	return bounding;
    }

    static geo geo_center (int c, geo* geos) {
	geo out = { 0, 0 };
	unsigned int i;

	if (c == 0) {
	    return out;
	}

	double lat0 = geos[0].lat;
	double lon0 = geos[0].lon;
	double lat1 = geos[0].lat;
	double lon1 = geos[0].lon;

	for (i = 1; i < c; i++) {
	    lat0 = MIN (lat0, geos[i].lat);
	    lon0 = MIN (lon0, geos[i].lon);
	    lat1 = MAX (lat1, geos[i].lat);
	    lon1 = MAX (lon1, geos[i].lon);
	}

	out.lat = (lat0 + lat1)/2.0 ;
	out.lon = (lon0 + lon1)/2.0 ;

	return out;
    }

    static double geo_diameter (int c, geo* geos) {
	double diameter = 0;
	unsigned int i, j;

	if (c < 2) {
	    return 0;
	}

	for (i = 0; i < c-1; i++) {
	    double lata = DEGTORAD * geos[i].lat;
	    double lona = DEGTORAD * geos[i].lon;

	    for (j = i+1; j < c; j++) {
		// inline 2 element geo distance
		// note: going for replication of conversion for B point, instead of allocating memory
		// i.e. trading space (and complexity of managing it) for time

		double latb = DEGTORAD * geos[j].lat;
		double lonb = DEGTORAD * geos[j].lon;
		double d    = geo_distance (lata, lona, latb, lonb);

		diameter = MAX (diameter, d);
	    }
	}

	double meters = 6371009 * diameter;
	return meters;
    }

    static double point_distance (point* a, point* b) {
	return hypot (b->x - a->x,
		      b->y - a->y);
    }

    static double point_distance_list (int closed, int c, point* points) {
	unsigned int i, k;

	if (c < 2) {
	    return 0;
	}

	double d = 0;

	for (i = 1, k = 0; i < c ; i++, k++) {
	    d += hypot (points[i].x - points[k].x,
			points[i].y - points[k].y);
	}

	if (closed) {
	    d += hypot (points[c-1].x - points[0].x,
			points[c-1].y - points[0].y);
	}

	return d;
    }

    static pointbox point_bbox (int c, point* points) {
	unsigned int i;

	if (c == 0) {
	    pointbox bounding = { 0, 0, 0, 0 };
	    return bounding;
	}

	pointbox bounding = {
	    .x0 = points[0].x,
	    .y0 = points[0].y,
	    .x1 = points[0].x,
	    .y1 = points[0].y,
	};

	for (i = 1; i < c; i++) {
	    bounding.x0 = MIN (bounding.x0, points[i].x);
	    bounding.y0 = MIN (bounding.y0, points[i].y);
	    bounding.x1 = MAX (bounding.x1, points[i].x);
	    bounding.y1 = MAX (bounding.y1, points[i].y);
	}

	return bounding;
    }

    static point point_center (int c, point* points) {
	unsigned int i;
	point out = { 0, 0 };

	if (c == 0) {
	    return out;
	}

	double miny = points[0].y;
	double minx = points[0].x;
	double maxy = points[0].y;
	double maxx = points[0].x;

	for (i = 1; i < c; i++) {
	    miny = MIN (miny, points[i].y);
	    minx = MIN (minx, points[i].x);
	    maxy = MAX (maxy, points[i].y);
	    maxx = MAX (maxx, points[i].x);
	}

	out.y = (miny + maxy)/2.0 ;
	out.x = (minx + maxx)/2.0 ;

	return out;
    }

    static double point_diameter (int c, point* points) {
	unsigned int i, j;
	double diameter = 0;

	if (c < 2) {
	    return 0;
	}

	for (i = 0; i < c-1; i++) {
	    for (j = i+1; j < c; j++) {
		double d = hypot (points[i].x - points[j].x,
				  points[i].y - points[j].y);
		diameter = MAX (diameter, d);
	    }
	}

	return diameter;
    }
}

# References
# - https://core.ac.uk/download/pdf/131287229.pdf
# - https://github.com/BobLd/RamerDouglasPeuckerNetV2/blob/b3d00f43d0ed5951ea2b1ca86bedfa72bb3d42a4/RamerDouglasPeuckerNetV2.Test/RamerDouglasPeuckerNetV2/RamerDouglasPeucker.cs#L97-L111
# Modification:
# - special case threshold for distance (s) <= 0. Which puts tmax at +Inf (Div by zero).

# Solution based on FAQ 1.02 on comp.graphics.algorithms
#
# L = hypot( Bx-Ax, By-Ay )
#
#     (Ay-Cy)(Bx-Ax)-(Ax-Cx)(By-Ay)
# s = -----------------------------
#		  L^2
# dist = |s|*L
#
# =>
#
#	 | (Ay-Cy)(Bx-Ax)-(Ax-Cx)(By-Ay) |
# dist = ---------------------------------
#			L

critcl::ccode {
    static double rdp_threshold (point* args, unsigned int i, unsigned int j) {
	double x0 = args[i].x;
	double y0 = args[i].y;
	double x1 = args[j].x;
	double y1 = args[j].y;

	double dx = x1 - x0;
	double dy = y1 - y0;
	double s  = hypot (dy, dx);

	// If there is "no distance" at all, ensure to dismiss anything in between.
	if (s <= 0) { return 0; }

	// Non-singular distance, continue as normal

	double phi  = atan2 (dy, dx);
	double cphi = cos (phi);
	double sphi = sin (phi);
	double tmax = (fabs (cphi) + fabs (sphi))/s;
	double poly = 1 - tmax + tmax * tmax;
	double px   = poly/s;
	double a    = atan(fabs(sphi + cphi)*px);
	double b    = atan(fabs(sphi - cphi)*px);
	double pphi = MAX (a,b);
	double dmax = s * pphi;

	return dmax;
    }

    static void rdp_find_farthest (point* args, unsigned int i, unsigned int j, double* d, unsigned int* k) {
	double	     maxd = 0;
	unsigned int maxk = 0;
	unsigned int n;

	// integrated distance to line, with common parts moved out of the loop,
	// and splitting the loop per a==b vs a!=b.

	double ax = args[i].x;
	double ay = args[i].y;
	double bx = args[j].x;
	double by = args[j].y;

	if ((ax == bx) && (ay == by)) {
	    for (n = i+1; n < j; n++) {
		double cx = args[n].x;
		double cy = args[n].y;
		double d  = hypot(cx-ax,cy-ay);

		if (d <= maxd) continue;
		maxd = d;
		maxk = n;
	    }

	    *d = maxd;
	    *k = maxk;
	    return;
	}

	double hyp = hypot(bx-ax,by-ay);

	for (n = i+1; n < j; n++) {
	    double cx = args[n].x;
	    double cy = args[n].y;
	    double d  = fabs((ay-cy)*(bx-ax)-(ax-cx)*(by-ay));

	    if (d <= maxd) continue;
	    maxd = d;
	    maxk = n;
	}

	*d = maxd / hyp;
	*k = maxk;
    }

    static void rdp_core (char* keep, point* args, unsigned int i, unsigned int j) {
	if ((j-i) < 2) {
	    keep[i] = 1;
	    keep[j] = 1;
	    return;
	}

	double d;
	unsigned int k;

	rdp_find_farthest (args, i, j, &d, &k);

	double t = rdp_threshold (args, i, j);
	if (d <= t) {
	    keep[i] = 1;
	    keep[j] = 1;
	    return;
	}

	rdp_core (keep, args, i, k);
	rdp_core (keep, args, k, j);
    }
}

# ### ### ### ######### ######### #########
return
