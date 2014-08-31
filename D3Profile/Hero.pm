#
# Hero object for D3Profile package
#
package D3Profile::Hero;

use strict;
use Storable;
use JSON;
use LWP::UserAgent;

use Data::Dumper;

# Create and bless this object.  Should only be called by D3Profile->loadHero();
sub new {
  my ($class, $bnetid, $heroid) = @_;

  if ( !defined($bnetid) || !defined($heroid) ) {
    die "Error: must supply both battle tag and hero ID\n";
  }

  my $ua = LWP::UserAgent->new();
  my $res = $ua->request( HTTP::Request->new(GET => "http://us.battle.net/api/d3/profile/$bnetid/hero/$heroid") );
  if ( !$res->is_success) {
    die $res->status_line, "\n";
  }

  my $self = decode_json($res->content());
  return bless $self, $class;
}

sub load {
  my ($class, $file) = @_;

  if ( !defined($file) ) {
    die("Error: must specify file to load from\n");
  }

  my $self = retrieve($file);
  if ( ref($self) ne "D3Profile::Hero" ) {
    die("Error: stored object not D3Profile::Hero\n");
  }

  return bless $self, $class;
}

# Return the full list of slots available
sub slots {
  my $self = shift;

  if ( ref($self->{items}) eq 'HASH' ) {
    return keys %{ $self->{items} };
  }
  return undef;
}

# Return an item object found in the slotName
sub item {
  my ($self, $slotName) = @_;

  if ( defined($self->{items}->{$slotName}) ) {
    return $self->{items}->{$slotName};
  }
  return undef;
}

sub gearStatTotal {
  my ($self, $stat) = @_;

  return 0 if !defined($stat);

  my $sum = 0;
  foreach my $slot ($self->slots()) {
    my $item = $self->item($slot);
    $sum += $item->attribute($stat);
  }

  return $sum;
}

# Maybe only beneficial for OWE monks?
sub highestResist {
  my $self = shift;

  my %resists = ();
  foreach my $slot ($self->slots()) {
    my $item = $self->item($slot);
    if ( $item->resType ne "all" && $item->resType ne "none" ) {
      $resists{$item->resType()} += $item->res($item->resType);
    }
  }

  my $max = "none";
  my $maxValue = 0;
  foreach my $res (keys %resists) {
    if ( $resists{$res} > $maxValue ) {
      $max = $res;
      $maxValue = $resists{$res};
    }
  }

  return $max;
}

# Determine if a skill is activated or not
sub skillActivated {
  my ($self, $skill) = @_;

  return 0 if !defined($skill);

  foreach my $active ( @{$self->{skills}->{active}} ) {
    return 1 if ( $active->{skill}->{slug} eq $skill );
  }

  foreach my $passive ( @{$self->{skills}->{passive}} ) {
    return 1 if ( $passive->{skill}->{slug} eq $skill );
  }
}

sub activeSkills {
  my $self = shift;

  my @skills = ();
  foreach my $skill ( @{$self->{skills}->{active}} ) {
    push(@skills, $skill->{skill}->{name} .":". $skill->{rune}->{name});
  }

  return @skills;
}

sub passiveSkills {
  my $self = shift;

  my @skills = ();
  foreach my $skill ( @{$self->{skills}->{passive}} ) {
    push(@skills, $skill->{skill}->{name});
  }

  return @skills;
}

# Print text details about this hero
sub print {
  my $self = shift;

  printf $self->{name} ."\n";
  print  "="x45 ."\n";
  printf "Level:       %31d\n", $self->{level};
  printf "Paragon:     %31d\n", $self->{paragonLevel};
  printf "Elite Kills: %31s\n", D3Profile::commify($self->{kills}->{elites});
  printf "Damage:      %31s\n", D3Profile::commify($self->{stats}->{damage});
  printf "Crit Chance: %30.1f%%\n", $self->gearStatTotal("Crit_Percent_Bonus_Capped") * 100;
  printf "Crit Damage: %30d%%\n", $self->gearStatTotal("Crit_Damage_Percent") * 100;
  printf "Life:        %31s\n", D3Profile::commify($self->{stats}->{life});
  printf "Armor:       %31s\n", D3Profile::commify($self->{stats}->{armor});
  printf "Strength:    %31s\n", D3Profile::commify($self->{stats}->{strength});
  printf "Dexterity:   %31s\n", D3Profile::commify($self->{stats}->{dexterity});
  printf "Intelligence:%31s\n", D3Profile::commify($self->{stats}->{intelligence});
  printf "Vitality     %31s\n", D3Profile::commify($self->{stats}->{vitality});

  print "\n";
  print "Skills:\n";
  print "   Active:\n";
  foreach my $skill ( @{$self->{skills}->{active}} ) {
    print "      ". $skill->{skill}->{name} ." (". $skill->{rune}->{name} .")\n";
  }
  print "   Passive:\n";
  foreach my $skill ( @{$self->{skills}->{passive}} ) {
    print "      ". $skill->{skill}->{name} ."\n";
  }

  print "\n";
  print "Items:\n";

  if ( $self->item("mainHand") ) {
    printf "%15s | %s (%s)\n", "mainHand", $self->item("mainHand")->{name}, $self->item("mainHand")->{typeName}
  } else {
    printf "%15s | empty\n", "mainHand";
  }
  if ( $self->item("offHand") ) {
    printf "%15s | %s (%s)\n", "offHand", $self->item("offHand")->{name}, $self->item("offHand")->{typeName}
  } else {
    printf "%15s | empty\n", "offHand";
  }

  foreach my $slot (sort $self->slots()) {
    next if $slot eq "mainHand";
    next if $slot eq "offHand";
    if ( $self->item($slot) ) {
      printf "%15s | %s (%s)\n", $slot, $self->item($slot)->{name}, $self->item($slot)->{typeName};
    } else {
      printf "%15s | empty\n", $slot;
    }
  }
}

sub save {
  my ($self, $filename) = @_;

  if ( !defined($filename) ) {
    die("Error: no filename specified\n");
  }

  if ( !store($self, $filename) ) {
    die("Error storing to disk\n");
  }
}

1;
