# Download and parse Diablo 3 BattleNet Account information
#
# Usage:
#
#   use D3Profile;
#   my $profile = new D3Profile("Name-Number");
#   $profile->loadData();
#
# See http://blizzard.github.io/d3-api-docs/ for more details.
#
package D3Profile;

use strict;
use Storable;
use JSON;
use LWP::UserAgent;

use D3Profile::Hero;
use D3Profile::Item;

# Create and bless this object.  Must supply battlenetid
sub new {
  my ($class, $bnetid) = @_;

  if ( !defined($bnetid) ) {
    die "Error: must supply D3 ID\n";
  }

 # Fetch profile data from battle.net
  my $ua = LWP::UserAgent->new();
  my $res = $ua->request( HTTP::Request->new(GET => "http://us.battle.net/api/d3/profile/$bnetid/") );
  if ( !$res->is_success) {
    die "Error: ". $res->status_line, "\n";
  }

  my $self = decode_json($res->content()) || die "Error: Unable to parse hero $bnetid\n";
  $self->{battleTag} =~ s/#/-/;

  return bless $self, $class;
}

sub load {
  my ($class, $file) = @_;

  if ( !defined($file) ) {
    die("Error: must specify file to load from\n");
  }

  my $self = retrieve($file);
  if ( ref($self) ne "D3Profile" ) {
    die("Error: stored object not D3Profile\n");
  }

  return bless $self, $class;
}

# Return a list of hero names or the specific hero object
sub hero {
  my ($self, $heroName) = @_;

 # We have no heroes bail with nothing to do
  if ( ref($self->{heroes}) ne "ARRAY" ) {
    die "Error: No heroes in profile\n";
  }

 # didnt specify a hero, send back the list of names
  if ( !defined($heroName) ) {
    my @names = ();
    foreach my $hero (values $self->{heroes}) {
      push (@names, $hero->{name});
    }
    return @names;
  }

 # Send back the specific hero object
  foreach my $hero (values $self->{heroes}) {
    if ($hero->{name} eq $heroName ) { return $hero; }
  }

  return undef;
}

# Load everything specified
sub loadData {
  my ($self, @heroes) = @_;

  $self->loadHeroData(@heroes);
  $self->loadItemData(@heroes);
}

# Load only hero data specified
sub loadHeroData {
  my ($self, @heroes) = @_;

 # Default is to load all heroes
  if ( !@heroes ) {
    @heroes = $self->hero();
  }

 # first convert our heroes to actual D3Profile::Hero objects
  my @heroObjects = ();
  foreach my $heroName (@heroes) {
    my $hero = $self->hero($heroName);
    my $heroObject = new D3Profile::Hero($self->{battleTag}, $hero->{id});

    push(@heroObjects, $heroObject);
  }

  @{$self->{heroes}} = @heroObjects;
}

# Load item details for each hero specified
sub loadItemData {
  my ($self, @heroes) = @_;

 # Default is to load all hero item data
  if (!@heroes) {
    @heroes = $self->hero();
  }

 # Only load item data for heroes specified
  foreach my $heroName (@heroes) {
    my $hero = $self->hero($heroName);

   # Convert to actual D3Profile::Item objects
    my %itemObjects = ();
    foreach my $slot ($hero->slots()) {
      my $item = new D3Profile::Item($hero->item($slot)->{tooltipParams});
      $itemObjects{$slot} = $item;
    }

    $hero->{items} = \%itemObjects;
  }
}

# Print text information
sub print {
  my $self = shift;

  binmode(STDOUT, ":utf8");
  print $self->{battleTag} ."\n";
  print "="x45 ."\n";
  printf "Paragon Level:%30s\n", D3Profile::commify($self->{paragonLevel});
  printf "Total Kills:  %30s\n", D3Profile::commify($self->{kills}->{monsters});
  printf "Elite Kills:  %30s\n", D3Profile::commify($self->{kills}->{elites});
  print "\n";
  print "Heroes:\n";
  foreach my $hero ($self->hero()) {
    printf "   %-15s %25s\n", $hero, "lvl ". $self->hero($hero)->{level} ." ". $self->hero($hero)->{class} ;
  }
}

# Helper to add commas to numbers
sub commify {
  local $_  = shift;
  1 while s/^([-+]?\d+)(\d{3})/$1,$2/;
  return $_;
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
