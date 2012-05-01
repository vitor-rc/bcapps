#!/bin/perl

# A simple starmap w/ HA-Rey style constellations (see
# db/constellations.db and db/radecmag.asc for data).

# Constellation boundary data: http://cdsarc.u-strasbg.fr/viz-bin/nph-Cat/html?VI%2F49

# Slew of options:
#
# --xwid=800 x width
# --ywid=600 y width
# --fill=0,0,0 fill color (as r,g,b)
# --time=now draw starmap at this time (GMT)
# --stars=1 draw stars
# --lat=35.082463 latitude where to draw map
# --lon=-106.629635 longitude where to draw map

push(@INC,"/usr/local/lib");
require "bclib.pl";
require "bc-astro-lib.pl";
chdir(tmpdir());
$gitdir = "/home/barrycarter/BCGIT/";

# defaults
$now = time();
defaults("xwid=800&ywid=600&fill=0,0,0&time=$now&stars=1&lat=35.082463&lon=-106.629635");

# we use these a LOT, so putting them into global vars
($xwid, $ywid) = ($globopts{xwid}, $globopts{ywid});

# half width and height
$halfwid = $xwid/2;
$halfhei = $ywid/2;

# minimum dimension (so circle fits)
$mind = min($xwid, $ywid);

# the X graticule starts at $xwid/2-$mind/2, ends at $xwid/2+$mind/2
($xs, $xe) = ($xwid/2-$mind/2, $xwid/2+$mind/2);

# similarly for the y graticule
($ys, $ye) = ($ywid/2-$mind/2, $ywid/2+$mind/2);

debug("HW: $halfwid, $halfhei");

# write to fly file
open(A, ">map.fly");

# create a blank map (circle and graticule)
print A << "MARK";
new
size $xwid,$ywid
fill 0,0,$globopts{fill}
circle $halfwid,$halfhei,$mind,0,255,0
line $xs,$halfhei,$xe,$halfhei,128,0,0
line $halfwid,$ys,$halfwid,$ye,128,0,0
MARK
    ;

# draw stars if requested
if ($globopts{stars}) {draw_stars();}


close(A);
system("fly -i map.fly -o map.gif; xv map.gif");

# draw stars (program-specific subroutine)

sub draw_stars {
  # load star data
  # <h>my stars... hee hee</h>
  my(@stars) = split(/\n/,read_file("$gitdir/db/radecmag.asc"));

  for $i (@stars) {
    # split into ra/dec/mag
    my($ra, $dec, $mag) = split(/\s+/, $i);

    # convert to az/el
    my($az, $el) = radecazel2($ra, $dec, $globopts{lat}, $globopts{lon}, $globopts{t});
    debug("AZEL: $az,$el");
  }


}

