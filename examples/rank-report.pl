#!/usr/bin/perl
#
# Generate text reports on Greater Rift trends
#
# Display usage using the '-h' flag
#

use strict;
use Getopt::Long qw( :config no_ignore_case bundling );;
use D3Profile;
use D3Ranks;

my $report_dir = ".";
my $rank_cache_dir = "ranks";
my $profile_cache_dir = "ranks/profiles";

my $era = 1;
my $rankCount = 10;
my $no_download = 0;
my $quiet = 0;

my %options = (
  "q|quiet" => \$quiet,
  "c|count=i" => \$rankCount,
  "e|era=i" => \$era,
  "no-download" => \$no_download,
  "reports-dir=s" => \$report_dir,
  "rank-cache-dir=s" => \$rank_cache_dir,
  "profile-cache-dir=s" => \$profile_cache_dir,
  "h|help" => sub { usage(); exit(0); },
);

my %PROFILES = ();
my %ACTIVE_SKILLS = ();
my %PASSIVE_SKILLS = ();

my %MAINHAND_WEAPON = ();
my %OFFHAND_WEAPON = ();
my %WEAPON_COMBO = ();

$| = 1;

# Store all the D3Ranks objects, also master list of rankClass
my %RANKINGS = (
  "rift-barbarian" => undef,
  "rift-crusader" => undef,
  "rift-dh" => undef,
  "rift-monk" => undef,
  "rift-wd" => undef,
  "rift-wizard" => undef,
  "rift-hardcore-barbarian" => undef,
  "rift-hardcore-crusader" => undef,
  "rift-hardcore-dh" => undef,
  "rift-hardcore-monk" => undef,
  "rift-hardcore-wd" => undef,
  "rift-hardcore-wizard" => undef,
);

# Actuall class name for each rankClass
my %CLASSNAMES = (
  "rift-barbarian" => "barbarian",
  "rift-crusader" => "crusader",
  "rift-dh" => "deamon-hunter",
  "rift-monk" => "monk",
  "rift-wd" => "witch-doctor",
  "rift-wizard" => "wizard",
  "rift-hardcore-barbarian" => "barbarian",
  "rift-hardcore-crusader" => "crusader",
  "rift-hardcore-dh" => "deamon-hunter",
  "rift-hardcore-monk" => "monk",
  "rift-hardcore-wd" => "witch-doctor",
  "rift-hardcore-wizard" => "wizard",
);

# Boolean hardcore values
my %HARDCORE = (
  "rift-barbarian" => 0,
  "rift-crusader" => 0,
  "rift-dh" => 0,
  "rift-monk" => 0,
  "rift-wd" => 0,
  "rift-wizard" => 0,
  "rift-hardcore-barbarian" => 1,
  "rift-hardcore-crusader" => 1,
  "rift-hardcore-dh" => 1,
  "rift-hardcore-monk" => 1,
  "rift-hardcore-wd" => 1,
  "rift-hardcore-wizard" => 1,
);

GetOptions(%options) or die ("Error in command line arguments\n");

# Download or load greater rift rank data
foreach my $rankClass (keys %RANKINGS) {
  if ( $no_download ) {
    print "Loading $rankClass ranks..." unless $quiet;
    $RANKINGS{$rankClass} = load D3Ranks("$rank_cache_dir/$rankClass");
    print "done\n" unless $quiet;
  } else {
    print "Downloading $rankClass ranks..." unless $quiet;
    $RANKINGS{$rankClass} = new D3Ranks($rankClass, { era => $era, count => $rankCount });
    $RANKINGS{$rankClass}->save("$rank_cache_dir/$rankClass");
    print "done\n" unless $quiet;
  }

 # Initialize hash data
  $ACTIVE_SKILLS{$rankClass} = { };
  $PASSIVE_SKILLS{$rankClass} = { };
  $MAINHAND_WEAPON{$rankClass} = { };
  $OFFHAND_WEAPON{$rankClass} = { };
  $WEAPON_COMBO{$rankClass} = { };
}

# Determine if we need to download profile data or use existing cache
foreach my $rankClass (keys %RANKINGS) {
  my $rankings = $RANKINGS{$rankClass};

  print "Loading $rankClass profiles..." unless $quiet;
  foreach my $rank ($rankings->rows()) {
    my $btag = $rank->battleTag();

    if ( !$no_download && (!stat("$profile_cache_dir/$btag") || (stat("$profile_cache_dir/$btag"))[9] < $rank->date() )) {
      print "Fetching $btag data ($rankClass)..." unless $quiet;
      my $profile = new D3Profile($btag);
      $profile->loadData();
      $profile->save("$profile_cache_dir/$btag");
      print "done\n" unless $quiet;

    } else {
      if ( stat("$profile_cache_dir/$btag") ) {
        my $profile = load D3Profile("$profile_cache_dir/$btag");
        updateStats($profile, $rankClass);
      }
    }
  }
  print "done\n" unless $quiet;
  writeClassStats($rankClass);
}

# Final repott generation
writeClassCompareStats();

# Usage statemenet
sub usage {
  print "\n";
  print "Usage: $0 [-e|era=#] [-c|count=#] [-q|--quiet] [--no-download]\n";
  print "          [--reports-dir=<dir>] [--rank-cache-dir=<dir>] [--profile-cache-dir=<dir>]\n";
  print "\n";
  print "  -e|--era=#       Find greater rift rankings for era.  Default is: $era\n";
  print "  -c|--count=#     Return top # of rank profiles. Default is: $rankCount\n";
  print "\n";
  print "  --no-download    Use existing cache data to generate reports.\n";
  print "\n";
  print "  --reports-dir=<dir>       Location to store report text files.  Default is: $report_dir\n";
  print "  --rank-cache-dir=<dir>    Location to store ranking cache data.  Default is: $rank_cache_dir\n";
  print "  --profile-cache-dir=<dir> Location to store profile cache data.  Default is: $profile_cache_dir\n";
  print "\n";
}

# Compare greater rift achievements by class
sub writeClassCompareStats {
  print "Writing class compare report..." unless $quiet;

  open(FOUT, ">$report_dir/rift-all.txt") or die "Unable to open $report_dir/rift-all.txt: $!\n";

  my %MIN_TIER = ();
  my %MAX_TIER = ();
  my %TIER_SUM = ();
  my %TIER_COUNT = ();

  foreach my $rankClass (keys %RANKINGS) {
    my $rankings = $RANKINGS{$rankClass};
    $MIN_TIER{$rankClass} = 99;
    foreach my $rank ($rankings->rows()) {
      $MIN_TIER{$rankClass} = $rank->tier() if $rank->tier() < $MIN_TIER{$rankClass};
      $MAX_TIER{$rankClass} = $rank->tier() if $rank->tier() > $MAX_TIER{$rankClass};
      $TIER_SUM{$rankClass} += $rank->tier();
      $TIER_COUNT{$rankClass}++;
    }
  }

 # Sort by max tier achieved
  print FOUT "---------------------------+------+------+--------\n";
  print FOUT "                     class |  min |  max |   avg\n";
  print FOUT "---------------------------+------+------+--------\n";
  foreach my $rankClass (sort {$MAX_TIER{$b} <=> $MAX_TIER{$a}} keys %RANKINGS) {
    printf FOUT " %25s | %4d | %4d | %2.2f\n",
	$rankClass,
	$MIN_TIER{$rankClass},
	$MAX_TIER{$rankClass},
	$TIER_SUM{$rankClass}/$TIER_COUNT{$rankClass};
  }

  close(FOUT);
  print "done\n" unless $quiet;
}

# Write rankClass report to text file
sub writeClassStats {
  my $rankClass = shift;

  print "Writing $rankClass report..." unless $quiet;
  open(FOUT, ">$report_dir/$rankClass.txt") or die "Unable to open $report_dir/$rankClass.txt: $!\n";

  my $rankings = $RANKINGS{$rankClass};
  print FOUT $rankings->name() ."\n";
  print FOUT "\n";
  print FOUT "---------------------------+----------------------+-------\n";
  print FOUT "           skill           |         rune         | count\n";
  print FOUT "---------------------------+----------------------+-------\n";
  foreach (sort {$ACTIVE_SKILLS{$rankClass}->{$b} <=> $ACTIVE_SKILLS{$rankClass}->{$a}} keys %{$ACTIVE_SKILLS{$rankClass}}) {
    next if $ACTIVE_SKILLS{$rankClass}->{$_} < 5;
    next if $_ eq "";
    next if $_ eq ":";

    my ($skill, $rune) = split(":", $_);
    printf FOUT " %s | %s | %4d\n", substr($skill." "x25, 0, 25), substr($rune." "x20, 0, 20), $ACTIVE_SKILLS{$rankClass}->{$_};
  }
  print FOUT "\n";

  print FOUT "---------------------------+-------\n";
  print FOUT "          passive          | count\n";
  print FOUT "---------------------------+-------\n";
  foreach (sort {$PASSIVE_SKILLS{$rankClass}->{$b} <=> $PASSIVE_SKILLS{$rankClass}->{$a}} keys %{$PASSIVE_SKILLS{$rankClass}}) {
    next if $PASSIVE_SKILLS{$rankClass}->{$_} < 5;
    next if $_ eq "";

    printf FOUT " %s | %4d\n", substr($_." "x25, 0, 25), $PASSIVE_SKILLS{$rankClass}->{$_};
  }
  print FOUT "\n";

  print FOUT "---------------------------+----------------------+-------\n";
  print FOUT "         mainhand          |       offhand        | count\n";
  print FOUT "---------------------------+----------------------+-------\n";
  foreach (sort {$WEAPON_COMBO{$rankClass}->{$b} <=> $WEAPON_COMBO{$rankClass}->{$a}} keys %{$WEAPON_COMBO{$rankClass}}) {
    next if $WEAPON_COMBO{$rankClass}->{$_} < 5;
    next if $_ eq "";
    next if $_ eq ":";

    my ($mainHand, $offHand) = split(":", $_);
    printf FOUT " %s | %s | %4d\n", substr($mainHand." "x25, 0, 25), substr($offHand." "x20, 0, 20), $WEAPON_COMBO{$rankClass}->{$_};
  }
  
  close(FOUT);
  print "done\n" unless $quiet;
}

# Parse profile data and add to rankClass stats
sub updateStats {
  my ($profile, $rankClass) = @_;

 # Look through list if heroes sorted by last time of update
  my $hero = undef;
  foreach (sort {$profile->hero($b)->{"last-updated"} cmp $profile->hero($a)->{"last-updated"}} $profile->hero()) {
    $hero = $profile->hero($_);

    # Pick the first hero of the right class unless:
    #    - any blank skills activated
    #    - hardcore/softcore doesnt match
    #    - is not level 70
     if ( $hero->{class} eq $CLASSNAMES{$rankClass} ) {
       next if $hero->skillActivated("");
       next if $hero->{hardcore} != $HARDCORE{$rankClass};
       next if $hero->{level} ne "70";
       last;
    }
  }

 # Recheck class, hero, harcore, and level in case no heroes matched
  return if $hero->{class} ne $CLASSNAMES{$rankClass};
  return if $hero->skillActivated("");
  return if $hero->{hardcore} != $HARDCORE{$rankClass};
  return if $hero->{level} ne "70";

 # Update active/passive skills used
  foreach my $skill ($hero->activeSkills()) {
    $ACTIVE_SKILLS{$rankClass}->{$skill}++;
  }
  foreach my $skill ($hero->passiveSkills()) {
    $PASSIVE_SKILLS{$rankClass}->{$skill}++;
  }

 # If there is a mainhand, add that to the list
  next if !defined($hero->item("mainHand"));
  $MAINHAND_WEAPON{$rankClass}->{ $hero->item("mainHand")->{name} }++;

 # If there is an offhand item equiped, add that to stats and update weaponCombo
  my $weaponCombo = $hero->item("mainHand")->{name};
  if ( defined($hero->item("offHand") ) ) {
    if ( $hero->item("offHand") ) {
      $OFFHAND_WEAPON{$rankClass}->{ $hero->item("offHand")->{name} }++;
      $weaponCombo .= ":".  $hero->item("offHand")->{name};
    }
  }
  $WEAPON_COMBO{$rankClass}->{$weaponCombo}++;
}


