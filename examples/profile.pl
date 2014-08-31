#!/usr/bin/perl
#
# A simple script to view profile information
#

use strict;
use D3Profile;

if ( !@ARGV ) {
  print "Usage: $0 <battleTag> [<Hero>]\n";
  exit(1);
}

my $battleTag = shift @ARGV;
$battleTag =~ s/#/-/;

my $heroName = shift @ARGV;

my $profile = new D3Profile($battleTag);
if (defined($heroName)) {
  $profile->loadData($heroName);
  $profile->hero($heroName)->print();

} else {
  $profile->print();
}
