#!/usr/bin/perl

use strict;
use D3Ranks;
use D3Profile::Hero;
use D3Profile;

use Getopt::Long qw( :config no_ignore_case bundling );
my $verbose = 0;
my %options = (
  "v|verbose" => \$verbose,
);
GetOptions(%options) or die ("Error in command line arguments\n");

if ( !@ARGV ) {
  print "Usage: $0 <rank-file> [ <rank #> ] [-v]\n";
  exit(0);
}
if ( !stat($ARGV[0]) ) {
  print "Error: Unable to open file $ARGV[0]\n";
  exit(0);
}

my $profile = load D3Ranks($ARGV[0]);
my $rank = undef;

if ( defined($ARGV[1]) ) {
  $rank = $profile->byRank($ARGV[1].".");
}

if ( $rank ) {
  $rank->print();
  if ( $rank->hero() ) {
    my $hero = $rank->hero();
    $hero->print();

    if ( $verbose ) {
      foreach my $slot ($hero->slots()) {
        if ( defined($hero->item($slot)) ) {
          $hero->item($slot)->print();
        }
      }
    }
  }
} else {
  $profile->print();
}
