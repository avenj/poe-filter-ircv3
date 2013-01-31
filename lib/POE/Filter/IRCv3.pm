package POE::Filter::IRCv3;
our $VERSION = '0.01';

use strictures 1;
use Carp;

use parent 'POE::Filter';

my $g = {
  space           => qr/\x20+/o,
  trailing_space  => qr/\x20*/o,
};

my $irc_regex = qr/^
  (?:
    \x40                # '@'-prefixed IRCv3.2 messsage tags.
    (\S+)               # [tags] Semi-colon delimited key=value list
    $g->{space}
  )?
  (?:
    \x3a                #  : comes before hand
    (\S+)               #  [prefix]
    $g->{space}         #  Followed by a space
  )?                    # but is optional.
  (
    \d{3}|[a-zA-Z]+     #  [command]
  )                     # required.
  (?:
    $g->{space}         # Strip leading space off [middle]s
    (                   # [middle]s
      (?:
        [^\x00\x0a\x0d\x20\x3a]
        [^\x00\x0a\x0d\x20]*
      )                 # Match on 1 of these,
      (?:
        $g->{space}
        [^\x00\x0a\x0d\x20\x3a]
        [^\x00\x0a\x0d\x20]*
      )*                # then match as many of these as possible
    )
  )?                    # otherwise dont match at all.
  (?:
    $g->{space}\x3a     # Strip off leading spacecolon for [trailing]
    ([^\x00\x0a\x0d]*)  # [trailing]
  )?                    # [trailing] is not necessary.
  $g->{'trailing_space'}
$/x;


sub COLONIFY () { 0 }
sub DEBUG    () { 1 }
sub BUFFER   () { 2 }


sub new {
  my ($class, %params) = @_;
  $params{uc $_} = delete $params{$_} for keys %params;

  my $self = [
    $params{'COLONIFY'} || 0,
    $params{'DEBUG'}    || 0,
    []  ## BUFFER
  ];

  bless $self, $class;
}

sub clone {
  my ($self) = @_;
  my $nself = [@$self];
  $nself->[BUFFER] = [];
  bless $nself, ref $self
}

sub debug {
  my ($self, $value) = @_;
  return $self->[DEBUG] = $value if defined $value;
  $self->[DEBUG]
}

sub colonify {
  my ($self, $value) = @_;
  return $self->[COLONIFY] = $value if defined $value;
  $self->[COLONIFY]
}

sub get_one_start {
  my ($self, $raw_lines) = @_;
  push @{ $self->[BUFFER] }, $_ for @$raw_lines;
}

sub get_pending {
  my ($self) = @_;
  @{ $self->[BUFFER] } ? [ @{ $self->[BUFFER] } ] : ()
}

sub get_one {
  my ($self) = @_;
  my $events = [];

  if (my $raw_line = shift @{ $self->[BUFFER] }) {
    warn "-> $raw_line \n" if $self->[DEBUG];

    if ( my($tags, $prefix, $command, $middles, $trailing)
       = $raw_line =~  m/$irc_regex/ ) {

      my $event = { raw_line => $raw_line };

      if ($tags) {
        for my $tag_pair (split /;/, $tags) {
          my ($thistag, $thisval) = split /=/, $tag_pair;
          $event->{tags}->{$thistag} = $thisval
        }
      }

      $event->{prefix}  = $prefix if $prefix;
      $event->{command} = uc $command;

      push @{ $event->{params} }, split(/$g->{space}/, $middles)
        if defined $middles;
      push @{ $event->{params} }, $trailing
        if defined $trailing;

      push @$events, $event;
    } else {
      warn "Received malformed IRC input: $raw_line\n";
    }
  }

  $events
}

sub put {
  my ($self, $events) = @_;
  my $raw_lines = [];

  for my $event (@$events) {

    if ( ref $event eq 'HASH' ) {
      my $raw_line;

      if ( ref $event->{tags} eq 'HASH' && keys %{ $event->{tags} } ) {
          $raw_line .= '@';
          my @tags = %{ $event->{tags} };
          while (my ($thistag, $thisval) = splice @tags, 0, 2) {
            $raw_line .= $thistag . ( defined $thisval ? '='.$thisval : '' );
            $raw_line .= ';' if @tags;
          }
          $raw_line .= ' ';
      }

      $raw_line .= ':' . $event->{prefix} . ' '
        if exists $event->{prefix};

      $raw_line .= $event->{command};

      if ( ref $event->{params} eq 'ARRAY'
        && (my @params = @{ $event->{params} }) ) {
          $raw_line .= ' ';
          my $param = shift @params;
          while (@params) {
            $raw_line .= $param . ' ';
            $param = shift @params;
          }
          $raw_line .= ':'
            if $self->[COLONIFY]
            or $event->{colonify}
            or $param =~ m/\x20/;
          $raw_line .= $param;
      }

      push @$raw_lines, $raw_line;
      warn "<- $raw_line \n" if $self->[DEBUG];
    } else {
      carp "($self) non-HASH passed to put(): '$event'";
      push @$raw_lines, $event if ref $event eq 'SCALAR';
    }

  }

  $raw_lines
}

1;


=pod

=head1 NAME

POE::Filter::IRCv3 - POE::Filter::IRCD with IRCv3.2 message tags

=head1 SYNOPSIS

  my $filter = IRC::Server::Pluggable::IRC::Filter->new(colonify => 1);

  ## Raw lines parsed to hashes:
  my $array_of_refs  = $filter->get( [ $line1, $line ... ] );

  ## Hashes deparsed to raw lines:
  my $array_of_lines = $filter->put( [ \%hash1, \%hash2 ... ] );

  ## Stacked with a line filter, suitable for Wheel usage, etc:
  my $ircd = IRC::Server::Pluggable::IRC::Filter->new(colonify => 1);
  my $line = POE::Filter::Line->new(
    InputRegexp   => '\015?\012',
    OutputLiteral => "\015\012",
  );
  my $filter = POE::Filter::Stackable->new(
    Filters => [ $line, $ircd ],
  );

=head1 DESCRIPTION

A L<POE::Filter> for IRC traffic derived from L<POE::Filter::IRCD>.

Adds support for IRCv3.2 message tags.

Like any proper L<POE::Filter>, there are no POE-specific bits involved 
here; the filter can be used stand-alone to parse IRC traffic.

=head2 get_one_start, get_one, get_pending

Implement the interface described in L<POE::Filter>.

See L</get>.

=head2 get

  my $events = $filter->get( [ $line, $another, ... ] );
  for my $event (@$events) {
    my $cmd = $event->{command};
    ## See below for other keys available
  }

Takes an ARRAY of raw lines and returns an ARRAY of hash references with 
the following keys:

=head3 command

The (uppercased) command or numeric.

=head3 params

An ARRAY containing the event parameters.

=head3 prefix

The sender prefix, if any.

=head3 tags

A HASH of key => value pairs matching IRCv3.2 "message tags" -- see 
L<http://ircv3.atheme.org>.

Note that a tag can be present, but have an undefined value.

=head2 put

  my $lines = $filter->put( [ $hash, $another_hash, ... ] );
  for my $line (@$lines) {
    ## Direct to socket, etc
  }

Takes an ARRAY of hash references matching those described in L</get> 
(documented above) and returns an ARRAY of raw IRC-formatted lines.

=head3 colonify

In addition to the keys described in L</get>, the B<colonify> option can be 
specified for specific events. This controls whether or not the last 
parameter will be colon-prefixed even if it is a single word. (Yes, IRC is 
woefully inconsistent ...)

Defaults to boolean false (off).

=head2 clone

Copy the filter object (with a cleared buffer).

=head2 debug

Turn on/off debug output.

=head1 AUTHOR

Derived from L<POE::Filter::IRCD>, which is copyright Chris Williams and 
Jonathan Steinert.

Adapted with IRCv3 extensions and other tweaks by Jon Portnoy <avenj@cobaltirc.org>

This module may be used, modified, and distributed under the same terms as 
Perl itself. 
Please see the license that came with your Perl distribution for details.

=head1 SEE ALSO

L<POE::Filter>

L<POE::Filter::IRCD>

L<POE::Filter::Line>

L<POE::Filter::Stackable>

L<IRC::Toolkit>

=cut
