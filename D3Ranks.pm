# Download and parse Diablo 3 BattleNet Ranking Information
#
# Usage:
#
# use D3Ranks;
# my $rankings = new D3Ranks("type");
#  or
# my $rankings = new D3Ranks("type", { era => 1, count => 10 });
#
# $rankings->rank(1)->print();
#
# See 'http://us.battle.net/d3/en/rankings/' for available "types".
#
package D3Ranks;

use strict;
use D3Ranks::Rank;

use Storable;
use Date::Parse;
use Time::Local;

use LWP::UserAgent;
use HTML::TableContentParser;
use HTML::Strip;

use Data::Dumper;

# Create and bless this object.  Must supply ranking URL
sub new {
  my ($class, $type, $params) = @_;

  if ( !defined($type) ) {
    die "Error: must supply ranking type\n";
  }
  if ( defined($params) && ref($params) ne 'HASH' ) {
    die "Error: parameters must be a hash reference\n";
  }

  my $self = {
    "_name" => undef,
    "_rows" => [()],
    "_byRank" => { },
    "_type" => $type,
    "era" => 1,
    "count" => 1000,
  };

  foreach my $key (keys %{$params}) {
    $self->{$key} = $params->{$key};
  }

 # Fetch the source HTML from URL
  my $ua = LWP::UserAgent->new();
  my $res = $ua->get("http://us.battle.net/d3/en/rankings/era/".$self->{era}."/".$self->{_type});
  if ( !$res->is_success) {
    die "Error: ". $res->status_line ."\n";
  }
  $self->{"_name"} = $res->title();

  D3Ranks::_populateRows($self, $res);
  return bless $self, $class;
}

sub load {
  my ($class, $file) = @_;

  if ( !defined($file) ) {
    die("Error: must specify file to load from\n");
  }

  my $self = retrieve($file);
  if ( ref($self) ne "D3Ranks" ) {
    die("Error: stored object not D3Ranks\n");
  }

  return bless $self, $class;
}

sub _populateRows {
  my ($self, $uaRes) = @_;

  my $hs = HTML::Strip->new();
  my $p = HTML::TableContentParser->new();
  my $tables = $p->parse($uaRes->content());

  my $table = shift @{$tables};
  for my $row (@{$table->{rows}}) {

    my @recordData = ();
    for my $col (@{$row->{cells}}) {
      my $data = $hs->parse($col->{data});

      $data =~ s///g;
      $data =~ s/\n//g;
      $data =~ s/	//g;
      $data =~ tr/ / /s;
      $data =~ s/^ //;
      $data =~ s/ $//;
      push(@recordData, $data);
    }
    next if ( @recordData != 5 );
    next if $recordData[0] > $self->{count};

   # Convert date to epoc...
    my ($second,$minute,$hour,$day,$month,$year,$zone) = strptime($recordData[4]);
    $recordData[4] = timelocal($second,$minute,$hour,$day,$month,$year);
    
    my $rank = new D3Ranks::Rank(@recordData);
    push (@{$self->{_rows}}, $rank);
    $self->{_byRank}->{$rank->number()} = $rank;
  }
}

sub name {
  my $self = shift;
  return($self->{_name});
}

sub rows {
  my $self = shift;
  return(@{ $self->{_rows} });
}

sub byRank {
  my ($self, $number) = @_;

  return undef if !defined($number);
  return undef if !defined($self->{_byRank}->{$number});
  return $self->{_byRank}->{$number};
}

sub type {
  my $self = shift;
  return($self->{_type});
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
