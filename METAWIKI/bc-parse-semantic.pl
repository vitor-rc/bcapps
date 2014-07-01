#!/bin/perl

# breaking out the subroutines in pbs-meta-pbs.pl to clean them up a bit

# PBS is "test case" but this "should" work w/ anything

# Problems w/ using just pure generated triples:

# [[date::deaths::some_character]] =>
# [[date::character::some_character]] (for example)

# [[char1::relation::char2]] => [[sourcedate::charater:char1+char2]]

# [[char1::sister::char2]] => [[char1::relative::char2 (sister)]] for example

# [[alias::relation::foo]] => [[character::relation::foo]] (ie,
# aliases must be canonized except for [[character::aka::alias]]

# "name date (species)" should have alias "name canon_number
# (species)" and insure date is first appearance

require "/usr/local/lib/bclib.pl";

my($metadir) = "/home/barrycarter/BCGIT/METAWIKI";

my(%triples);
my(%queries);

# load meta data (TODO: this is cheating, only one section so far)
for $i (`egrep -v '^<|^#|^\$' $metadir/pbs-meta.txt`) {
  chomp($i);
  my(@data) = split(/\,\s*/, $i);
  $meta{$data[0]} = [@data];
  unless (scalar @data == 4) {warn "LINE HAS !=4 elts: $i";}
}

# imagehashes
for $i (split(/\n/, read_file("largeimagelinks.txt"))) {
  $i=~s/^(.*?)\s+.*?\/([0-9a-f]+)\?.*$//;
  my($strip, $hash) = ($1, $2);
  $triples{$strip}{hash}{$hash} = "largeimagelinks";
  $triples{$strip}{class}{strip} = "largeimagelinks";
}

for $i (`cat $metadir/pbs.txt $metadir/pbs-cl.txt | egrep -v '^#|^\$'`) {
  # TODO: multirefs!
  # TODO: *_deaths
  # below allows for multiple dates
  unless ($i=~/^([\d\-,]+)\s+(.*)$/) {next;}

  # create hash from triples
  for $j (parse_semantic($1, $2)) {
    map(s/\'/&\#39;/g, @$j);
    my($source, $k, $target, $datasource) = @$j;

    # the hash of triples (we mostly don't the reverse annos, but put
    # them in anyway)
    $triples{$source}{$k}{$target} = $datasource;
    $triples{$target}{"-$k"}{$source} = $datasource;
#    debug("FOO",keys %{$triples{$target}});

    # determine relation type
    my($for, $rev, $stype, $ttype) = ("?", "?", "?", "?");
    if ($meta{$k}) {($for, $rev, $stype, $ttype) = @{$meta{$k}};}

    # classes for source and target...
    $triples{$source}{class}{$stype} = "$datasource ($source::$k::$target)";
    $triples{$target}{class}{$ttype} = "$datasource ($source::$k::$target)";

    # special things for characters
    for $l ($source, $target) {
      unless ($triples{$l}{class}{character}) {next;}

      # the character appears in $datasource
      $triples{$datasource}{character}{$l} = "$datasource ($source::$k::$target)";

      # if the character has parens in name and no species, note species
      # (note that a species triple will correctly override this)
      if ($l=~/\(.*?\)$/ && !$triples{$l}{species}) {
	$triples{$l}{species}{$1} = "NAME2SPECIES";
      }

      # if the character has a "date like" name, tag for addl step
      # TODO: make sure date is actual first appearance
      if ($l=~/^.*? \d{8} \(.*?\)/) {$datename{$l}=1;}
    }

    # if this is an alias, tag for later canonization
    if ($k eq "aka") {$canon{$target} = $source;}

    # for character to character relations, we do more
    if ($stype eq "character" && $ttype eq "character") {
      # create this as a 2 directional relation for both characters
      $triples{$source}{relative}{"$target ($for)"}="$datasource ($for/$rev)";
      $triples{$target}{relative}{"$source ($rev)"}="$datasource ($for/$rev)";
    }
  }
}

# post processing steps on the triple
warn "TESTING";
for $i (sort keys %triples) {

  # if character...
  if ($triples{$i}{class}{character}) {

    # is this an alias posing as a character?
    if ($triples{$i}{class}{alias}) {

      # find canon name
      my(@canon) = sort keys %{$triples{$i}{"-aka"}};
      if (scalar @canon >=2) {warn "WARNING: More than one canon name: $i";}
      my($canon) = $canon[0];

      # we no longer need "-aka" or the "character" class
      delete $triples{$i}{"-aka"};
      delete $triples{$i}{class}{character};

      # and reassign properties
      for $j (sort keys %{$triples{$i}}) {
	# "alias" class remains with the actual alias
	if ($j eq "class") {next;}

	# j2 is unsigned version of j
	my($j2) = $j;
	$j2=~s/^\-//;

	for $k (sort keys %{$triples{$i}{$j}}) {

	  # if $j is a negative relation ($dir is true), backwards assign
	  if ($j=~/^\-/) {
	    debug("NEGADD: $k/$j2/$canon, DELETE: $k/$j2/$i");
	    $triples{$k}{$j2}{$canon} = $triples{$k}{$j2}{$i};
	    # and delete original
	    delete $triples{$k}{$j}{$i};
	  } else {
	    debug("POSADD: $canon/$j/$k, DELETE: $i/$j/$k");
	    # if $j is a forward relation, assign it to the canon
	    $triples{$canon}{$j}{$k} = $triples{$i}{$j}{$k};
	    # and delete from the alias
	    delete $triples{$i}{$j}{$k};
	  }
	}
      }
    }
  }
}

# debug("TRIPLES",unfold({%triples}));

=item comment

    # if this is a "date name", fix it and reassign properties
    if ($i=~/^(.*?)\s+(\d{8})\s+\((.*?)\)$/) {
      my($name, $date, $species) = ($1, $2, $3);
      # how many times have we seen this name/species combo?
      my($newname) = "$name ($species) #".++$times{$name}{$species};
      # reassign properties to newname
      $triples{$newname} = $triples{$i};
      # TODO: this probably doesnt do what I want
      delete $triples{$i};
      # and remember oldname
      $triples{$newname}{reference_name}{$i} = "DATEDNAME";
      # let SQL handle the targets
      $queries{"UPDATE triples SET target='$newname' WHERE target='$i';"}=1;
    }
  }
}

=cut

debug("QUERIES:",unfold(%queries));
# debug("TRIPLES:",unfold(%triples));

die "TESTING";

# handle numbered names (sorting IS important here, earlier ones get first #s)
for $i (sort keys %datename) {
  $i=~/^(.*?)\s+(\d{8})\s+\((.*?)\)$/;
  my($name, $date, $species) = ($1, $2, $3);
  # how many times have we seen this name/species combo?
  my($aka) = "$name ($species) #".++$times{$name}{$species};
  debug("$i aka $aka");
  $triples{$aka}{aka}{$i} = "DATE2NAME";
}

# handle aliases
for $i (sort keys %canon) {
  debug("I: $i",unfold($triples{$i}));
  debug("CANON: $i -> $canon{$i} -> $canon{$canon{$i}}");
}

# "string" and "*" are useless types
# delete $triples{string};
# delete $triples{"*"};

# debug("TRIPLES:", keys %{$triples{'2002-01-07'}{character}{Pig}});

# once again excessively terse
  open(A,"|tee /tmp/triples2.txt|sqlite3 /usr/local/etc/metawiki/pbs/pbs-triples.db 1>/tmp/pbs2-myout.txt 2>/tmp/pbs2-myerr.txt");
  # open(A,">/tmp/mysql.txt");
  print A << "MARK";
DROP TABLE IF EXISTS triples;
CREATE TABLE triples (source, k, target, datasource);
CREATE INDEX i1 ON triples(source);
CREATE INDEX i2 ON triples(k);
CREATE INDEX i3 ON triples(target);
CREATE INDEX i4 ON triples(datasource);
-- data is single sourced only
CREATE UNIQUE INDEX i5 ON triples(source,k,target);
BEGIN;
MARK
;

for $i (sort keys %triples) {
  for $j (sort keys %{$triples{$i}}) {
    for $k (sort keys %{$triples{$i}{$j}}) {
      print A "INSERT OR IGNORE INTO triples VALUES('$i','$j','$k','$triples{$i}{$j}{$k}');\n";
    }
  }
}

# commit queries above and start new batch
print A "COMMIT;\nBEGIN;";

# the queries from the parsing
for $i (keys %queries) {
  print A $i;
}

print A "COMMIT;\n";

# TODO: put this in misc.sql
print A "DELETE FROM triples WHERE k='class' AND target IN ('*', 'string');\n";

close(A);

die "TESTING";

# write some other ANNOS
my($query) = << "MARK";
SELECT SUBSTR(datasource,1,10) AS ds,
 GROUP_CONCAT("[["||source||"::"||k||"::"||target||"]]", "NEWLINE") AS data
FROM triples GROUP BY ds ORDER BY ds;
MARK
;

for $i (sqlite3hashlist($query, "/usr/local/etc/metawiki/pbs/pbs-triples.db")) {
  debug("SOURCE: $i->{ds}");
  $i->{data}=~s/NEWLINE/\n/g;
  write_file($i->{data}, "/mnt/extdrive/GOCOMICS/pearlsbeforeswine/page-$i->{ds}.gif.txt");
}

=item parse_semantic($dates, $string)

Given $dates and a string like "[[x::y]]" (with several
variants), return semantic triples (including a 4th 'extra' field to
represent Semantic Internal Objects) and a string.

$string may have nested "[[x::y]]" constructions ($dates, however, may not)

Plus signs like [[x+y::...]] are treated like [[x::...]], [[y::...]]
and return a list of triples and strings

Details:

[[x::y]] - return triple [$dates,x,y] and string [[y]]
[[x::y::z]] - return triple [$x,$y,$z] and string [[z]]

In ALL cases, return "source=$dates" as the 4th parameter

NOTE: Alternation (the value of y or z being "foo|bar") is handled
automatically

TODO: if last parameter has plusses, it cannot be used by other triples

=cut

sub parse_semantic {
  my($dates, $string) = @_;
  my(@lol); # the return value

  # parse the dates and put them in the same "+" format I use for other lists
  # hash lets me check for non-date annotations
  my(@dates) = parse_date_list($dates);
  my(%dates) = list2hash(@dates);
  $dates = join("+",@dates);

  # temporarily replace colonless [[foo]] to avoid parsing issues
  $string=~s/\[\[([^:\[\]]+)\]\]/\001$1\002/g;
#  debug("ALPHA: $string");

  # parse anything with double colons (\001 is a marker to replace later)
  while ($string=~s/\[\[([^\[\]]+?::[^\[\]]+?)\]\]/\003/) {
    # determine the source, relation, and target
    my(@l) = split(/::/, $1);
    # if only two long, date is the implicit first parameter
    if (scalar @l == 2) {unshift(@l, $dates);}

#    debug("BETA",@l);
    # each element of @l can have +s
    for $i (split(/\+/, $l[0])) {
      for $j (split(/\+/, $l[1])) {
	for $k (split(/\+/, $l[2])) {
	  # restore thing we changed earlier, but wo brackets
#	  debug("GAMMA: $string");
	  $string=~s/\003/$k/;
#	  debug("DELTA: $string");
	  # restore brackets to $k
	  $k=~s/\001/[[/g;
	  $k=~s/\002/]]/g;
	  # if $i is one of the dates source is "SELF"
	  if ($dates{$i}) {
	    # debug("TRIPLE (SELF): $i/$j/$k/$i");
	    push(@lol, [$i,$j,$k,$i]);
	  } else {
	    for $l (@dates) {
	      # debug("TRIPLE (MULTI): $i/$j/$k/$l");
	      push(@lol, [$i,$j,$k,$l]);
	    }
	  }
	}
      }
    }
  }
  return @lol;
}

=item parse_date_list($string)

TODO: move this to bclib

Given a string like "2013-04-17-2013-04-19, 2013-04-22, 2013-04-23,
2013-04-30, 2013-05-01, 2013-05-06-2013-05-08, 2013-05-13-2013-05-15,
2013-05-20-2013-05-22, 2013-05-24, 2013-05-29", return a list of dates.

=cut

sub parse_date_list {
  my($datelist) = @_;
  my(@ret);

  for $i (split(/\,/,$datelist)) {
    # if datelist is date range (2002-06-03-2002-06-07), parse further
    if ($i=~/^(\d{4}-\d{2}-\d{2})\-(\d{4}-\d{2}-\d{2})$/) {
      for $j (str2time($1)/86400..str2time($2)/86400) {
	push(@ret, strftime("%Y-%m-%d", gmtime($j*86400)));
      }
    } else {
      push(@ret, $i);
    }
  }
  return @ret;
}