#
#
package D3Ranks::Rank;

use strict;
use Storable;
use POSIX qw/strftime/;

sub new {
  my ($class, @data) = @_;

  if ( @data != 5 ) {
    die "Error: unrecognized data record: @data\n";
  }

  my $self = {
    "_number" => $data[0],
    "_battleTag" => $data[1],
    "_tier" => $data[2],
    "_clearTime" => $data[3],
    "_date" => $data[4],
    "_hero" => undef,
  };

  $self->{_battleTag} =~ s/ Profile .*$//;
  $self->{_battleTag} =~ s/ #/-/;

  return bless $self, $class;
}

sub load {
  my ($class, $file) = @_;

  if ( !defined($file) ) {
    die("Error: must specify file to load from\n");
  }

  my $self = retrieve($file);
  if ( ref($self) ne "D3Ranks::Rank" ) {
    die("Error: stored object not D3Ranks::Rank\n");
  }

  return bless $self, $class;
}

sub number {
  my $self = shift;
  return $self->{_number};
}

sub battleTag {
  my $self = shift;
  return $self->{_battleTag};
}

sub tier {
  my $self = shift;
  return $self->{_tier};
}

sub clearTime {
  my $self = shift;
  return $self->{_clearTime};
}

sub date {
  my $self = shift;
  return $self->{_date};
}

sub hero {
  my ($self, $hero) = @_;

  if (defined($hero)) {
    $self->{_hero} = $hero;
  }
  return $self->{_hero};
}

sub print {
  my $self = shift;
  binmode(STDOUT, ":utf8");

  printf "%5d | %20s | %3d  | %13s | %19s\n",
	$self->number(),
	$self->battleTag(),
	$self->tier(),
	$self->clearTime(),
	strftime '%m/%d/%Y %H:%M:%S', localtime $self->date();
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
