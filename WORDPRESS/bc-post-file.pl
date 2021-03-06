#!/bin/perl

# Given a file (not stream) in the correct format (the output of
# bc-parse-wxr.pl), post it to my blog (or update) using wp-client

# NOTE: per https://core.trac.wordpress.org/ticket/38435
# wp_insert_post() does NOT take category slugs despite what the docs
# say

require "/usr/local/lib/bclib.pl";
my($out, $err, $res);

# these are the headers that are parsed separately so
# $options/@options below should ignore them

my(%excluded) = list2hash("ID", "post_category", "post_author");

# TODO: maybe tags and other taxonomy elements too?

# testing only (creds= credentials)
# TODO: get from file
my($creds) = "--ssh=barrycar\@bc4 --path=public_html/test20171209.barrycarter.org";

# determine list of categories/authors and cache as long as possible

my(%knowncats) = get_categories();
my(%knownusers) = get_users();

# read file + split into header and body

my($content, $file) = cmdfile();

# TODO: how many equals should I put here?
# NOTE: the "2" below handles the case "=====..." appears in post body

my($headers, $body) = split(/^======================+/m, $content, 2);

# parse header

my(%hash);
while ($headers=~s/^(.*?): (.*)$//m) {$hash{$1} = trim($2);}

# the options for the command
my(@options);

# push an option for categories and author if needed
push(@options, catlist_to_optstring($hash{post_category}));
push(@options, author_to_optstring($hash{post_author}));

# the other options
for $i (sort keys %hash) {
  if ($excluded{$i}) {next;}
  if ($hash{$i}=~/^\s*$/) {next;}
  debug("$i -> $hash{$i}");
  push(@options, "--$i='$hash{$i}'");
}

my($options) = join(" ", @options);

# the remote tmp file will be /tmp not /var/tmp/xx/xx

my($tmpfile) = my_tmpfile2();
my($remotetmp) = $tmpfile;
$remotetmp=~s%^.*/%/tmp/%;
write_file($body, $tmpfile);

# special case for new posts

my($postcommand) = $hash{ID}=~/^\d+$/?"update $hash{ID}":"create";

# rsync the file over
# TODO: consider removing the tmp files I'm creating remotely

($out, $err, $res) = cache_command2("rsync $tmpfile barrycar\@bc4:$remotetmp");

# run the command to add/update the post
($out, $err, $res) = cache_command2("wp post $postcommand $remotetmp $options $creds --debug");

# confirm

unless ($out=~/Success: (.*?) post (\d+)/) {
  die "POST FAILED: $out";
}

my($action, $id) = ($1,$2);

debug("ACTION: $action, ID: $id");

# TODO: if new post created, update input file w/ new ID

=item comment

# trimmed list of fields from
# https://developer.wordpress.org/reference/functions/wp_insert_post/

        'post_author'
        'post_date_gmt'
        'post_content'
        'post_title'
        'post_status'
        'post_type'
        'post_name'
        'post_category'
        'tags_input'
        'tax_input'
=cut

# program specific subroutines, no perldoc required

sub get_categories {

  my(%hash);

  # NOTE: uses global variables here
  my($out, $err, $res) = cache_command2("wp $creds term list category --format=csv", "age=+Infinity");

  for $i (split(/\n/, $out)) {
    my($id, $taxid, $name, $slug, $desc, $parent, $count) = csv($i);
    if ($id eq "term_id") {next;}
    $hash{$slug} = $id;
  }
  return %hash;
}

# program specific

sub get_users {

  my(%hash);

  ($out, $err, $res) = cache_command2("wp $creds user list --format=csv", "age=+Infinity");

  for $i (split(/\n/, $out)) {
    my($id, $login, $name, $email, $registered, $roles) = csv($i);
    if ($id eq "ID") {next;}
    $hash{$login} = $id;
  }
  return %hash;
}

# list of categories (a string like "foo,bar,uncategorized") to option
# string representing numerical values of those categories (eg,
# "--post-category=1,2")

sub catlist_to_optstring {

  my($catlist) = @_;
  my(%hash);

  # if catlist is empty, no --post_category option
  if ($catlist=~/^\s*$/) {return;}

  for $i (csv($catlist)) {

    # lower case for slug, allow spaces
    $i = lc(trim($i));

    # using a hash here allows us to ignore duplicates
    if ($knowncats{$i}) {$hash{$knowncats{$i}} = 1; next}

    # exiting entire prog here seems weird, does Perl throw exceptions?
    print "\n\nINVALID CATEGORY: $i\nKnown categories: ",join(", ", sort keys %knowncats),"\n\n";
    exit(1); 
  }
  return "--post_category=".join(",",sort keys %hash);
}

# convert author to option for --post-author

sub author_to_optstring {

  my($author) = @_;

  # normalize
  $author = lc(trim($author));

  # if no author, no --post-author option (will use default)
  if ($author eq "") {return;}

  if ($knownusers{$author}) {return "--post-author=$knownusers{$author}";}

  # exiting entire prog here seems weird, does Perl throw exceptions?
  print "\n\nINVALID AUTHOR: $author\nKnown authors: ",join(", ", sort keys %knownusers),"\n\n";
  exit(1);
}

