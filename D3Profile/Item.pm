#
# Hero object for D3Profile package
#
package D3Profile::Item;

use strict;
use Storable;
use JSON;
use LWP::UserAgent;

# Create and bless this object.  Should only be called by D3Profile->loadHero();
sub new {
  my ($class, $itemid) = @_;

  if ( !defined($itemid) ) {
    die "Error: must supply item ID\n";
  }

  my $tries = 3;
  my $ua = LWP::UserAgent->new();
  my $res;

  eval { $res = $ua->request( HTTP::Request->new(GET => "http://us.battle.net/api/d3/data/$itemid") ); };
  while ( !$res->is_success && $tries-- ) {
    eval { $res = $ua->request( HTTP::Request->new(GET => "http://us.battle.net/api/d3/data/$itemid") ); };
  }
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
  if ( ref($self) ne "D3Profile::Item" ) {
    die("Error: stored object not D3Ranks\n");
  }

  return bless $self, $class;
}

# Return the value of the atribute specified
sub attribute {
  my ($self, $attributeSearchName) = @_;

  my $total = 0;
  foreach my $attribute (keys %{$self->{attributesRaw}}) {
    if ( $attribute eq $attributeSearchName ) {
      $total += $self->{attributesRaw}->{$attribute}->{max};
    }
  }
  $total += $self->attributeFromGems($attributeSearchName);
  return $total;
}

# Return the sum of the attribute values from all gems socketed
sub attributeFromGems {
  my ($self, $attributeSearchName) = @_;

  my $attributeSum = 0;

  return undef if !defined($self->{gems});
  return undef if !defined($attributeSearchName);
  foreach my $gem (@{$self->{gems}}) {
    foreach my $attribute (keys %{$gem->{attributesRaw}}) {
      if ( $attribute eq $attributeSearchName ) {
        $attributeSum += $gem->{attributesRaw}->{$attribute}->{max};
      }
    }
  }
  return $attributeSum;
}

# Is weapon or not
sub isWeapon {
  my $self = shift;

  if ( defined($self->{attacksPerSecond}) ) {
    return 1;
  }
  return 0;
}

# Has sockets or not
sub hasSockets {
  my $self = shift;

  foreach my $attribute (keys %{$self->{attributesRaw}}) {
    if ( $attribute eq "Sockets" ) {
      return $self->{attributesRaw}->{$attribute}->{max};
    }
  }
  return 0;
}

# Weapon damage of the item, or 0 if not a weapon
sub weaponDamage {
  my $self = shift;

  return 0 if !$self->isWeapon();

  my $min = 0;
  my $max = 0;
  foreach my $attribute (keys %{$self->{attributesRaw}}) {
    if ( $attribute =~ m/^Damage_Weapon_Min/ || $attribute =~ m/^Damage_Weapon_Bonus_Min/ ) {
      $min += $self->{attributesRaw}->{$attribute}->{max};
      $max += $self->{attributesRaw}->{$attribute}->{max};
    }
    if ( $attribute =~ m/^Damage_Weapon_Delta/ || $attribute =~ m/^Damage_Weapon_Bonus_Delta/ ) {
      $max += $self->{attributesRaw}->{$attribute}->{max};
    }
  }

  my $avgDmg = ($min+$max)/2;

  return $avgDmg;
}

# Average Damage value
sub avgDamage {
  my $self = shift;

  my $min = $self->attribute("Damage_Min#Physical");
  my $max = $self->attribute("Damage_Min#Physical");
  $max += $self->attribute("Damage_Delta#Physical");

  $min += $self->attributeFromGems("Damage_Min#Physical");
  $max += $self->attributeFromGems("Damage_Min#Physical");
  $max += $self->attributeFromGems("Damage_Delta#Physical");

  my $avgDmg = ($min+$max)/2;
  return $avgDmg;
}

# Attack speed of the item, or 0 if not a weapon
sub attackSpeed {
  my $self = shift;

  return undef if !$self->isWeapon();
  return $self->attribute("Attacks_Per_Second_Item");
}

# Return increased attack speed percent
sub ias {
  my $self = shift;

  return $self->attribute("Attacks_Per_Second_Percent");
}

# Return elemental damage bonus
sub elemental {
  my ($self, $type) = @_;

  if ( defined($type) ) {
    return $self->attribute("Damage_Dealt_Percent_Bonus#$type");
  }
  foreach my $attribute (%{$self->{attributesRaw}}) {
    if ( $attribute =~ m/^Damage_Dealt_Percent_Bonus#(.*)$/ ) {
      return $self->{attributesRaw}->{$attribute}->{max};
    }
  }
  return undef;
}

# Return total critical hit damage, gems included
sub critDmg {
  my $self = shift;

  return $self->attribute("Crit_Damage_Percent");
}

# Return total critical hit chance
sub crit {
  my $self = shift;

  return $self->attribute("Crit_Percent_Bonus_Capped");
}

# Return the total armor for this item
sub armor {
  my $self = shift;

  return $self->{armor}->{max} if defined($self->{armor}->{max});
  return undef;
}

# Return the type of resistance this object has
sub resType {
  my $self = shift;

  foreach my $attribute (keys %{$self->{attributesRaw}}) {
    if ( $attribute =~ m/Resistance#(.*)$/ ) {
      return $1;
    }
    if ( $attribute =~ m/Resistance_All/ ) {
      return "all";
    }
  }
  return "none";
}

# Return the total resistance based on type specified
sub res {
  my ($self, $type) = @_;

 # Default type is resist all
  my $resname = "Resistance_All";
  if ( defined($type) ) {
    $resname = "Resistance#$type";
  }

  my $resSum += $self->attribute($resname);
  return $resSum;
}

# Return the strength attribute
sub str {
  my $self = shift;

  my $sum = $self->attribute("Strength_Item");
  return $sum;
}

# Return the dexterity attribute
sub dex {
  my $self = shift;

  my $sum = $self->attribute("Dexterity_Item");
  return $sum;
}

# Return the intelligence attribute
sub int {
  my $self = shift;

  my $sum = $self->attribute("Intelligence_Item");
  return $sum;
}

# Return the vitality attribute
sub vit {
  my $self = shift;

  my $sum = $self->attribute("Vitality_Item");
  return $sum;
}

# Life % increase
sub life {
  my $self = shift;

  my $sum = $self->attribute("Hitpoints_Max_Percent_Bonus_Item");
  return $sum;
}

# Save item to file
sub save {
  my ($self, $filename) = @_;

  if ( !defined($filename) ) {
    die("Error: no filename specified\n");
  }

  if ( !store($self, $filename) ) {
    die("Error storing to disk\n");
  }
}

# Print this item
sub print {
  my $self = shift;

  binmode(STDOUT, ":utf8");

  print "\n";
  print $self->{name} ." : ". $self->{typeName} ."\n";
  print "="x60 ."\n";
  printf "Level: %2d\n", $self->{requiredLevel} ."\n";
  if ( defined($self->{attributes}->{primary}) ) {
    print "Primary Stats:\n";
    foreach my $stat (@{$self->{attributes}->{primary}}) {
      printf "%60s\n", $stat->{text};
    }
  }
  print "\n";
  if ( defined($self->{attributes}->{secondary}) ) {
    print "Secondary Stats:\n";
    foreach my $stat (@{$self->{attributes}->{secondary}}) {
      printf "%60s\n", $stat->{text};
    }
  }
}

1;
