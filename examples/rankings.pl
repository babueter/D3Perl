#!/usr/bin/perl
#
# Simple example to display greater rift ranks
#

use strict;
use D3Ranks;

my @RANKINGS = (
  "rift-barbarian",
  "rift-crusader",
  "rift-dh",
  "rift-monk",
  "rift-wd",
  "rift-wizard",
  "rift-hardcore-barbarian",
  "rift-hardcore-crusader",
  "rift-hardcore-dh",
  "rift-hardcore-monk",
  "rift-hardcore-wd",
  "rift-hardcore-wizard",
);

if ( !@ARGV ) {
  print "\n";
  print "Usage: $0 <rank type> [count]\n";
  print "\tvalid rank types are:\n";
  foreach (@RANKINGS) {
    print "\t\t$_\n";
  }
  print "\n";
  exit(1);
}

my $rankClass = shift @ARGV;
my $count = shift @ARGV;
$count = 10 if !defined($count);

my $rankings = new D3Ranks($rankClass, { count => $count });
print "--------------------------------------------------------------------------\n";
print " ". $rankings->name() ."\n";
print "------+----------------------+------+---------------+---------------------\n";
print " rank |           battle tag | tier |    clear time | Date\n";
print "------+----------------------+------+---------------+---------------------\n";
foreach my $rank ($rankings->rows()) {
  $rank->print();
}

