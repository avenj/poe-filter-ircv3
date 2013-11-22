package POE::Filter::IRCv3;
use strict; use warnings FATAL => 'all';
use Carp;

BEGIN {
  if (eval { require POE::Filter; 1 }) {
    our @ISA = 'POE::Filter';
  }
}

=pod

=for Pod::Coverage COLONIFY DEBUG BUFFER SPCHR

=cut

sub COLONIFY () { 0 }
sub DEBUG    () { 1 }
sub BUFFER   () { 2 }
sub SPCHR    () { "\x20" }

sub new {
  my ($class, %params) = @_;
  map {; $params{uc $_} = $params{$_} } keys %params;
  bless [
    ($params{'COLONIFY'} || 0),
    ($params{'DEBUG'}    || $ENV{POE_FILTER_IRC_DEBUG} || 0),
    []  ## BUFFER
  ], $class
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

sub get {
  my @events;
  for my $raw_line (@{ $_[1] }) {
    warn " >> '$raw_line'\n" if $_[0]->[DEBUG];
    if (my $event = _parseline($raw_line)) {
      push @events, $event;
    } else {
      carp "Received malformed IRC input: $raw_line";
    }
  }
  \@events
}

sub get_one {
  my ($self) = @_;
  my @events;
  if (my $raw_line = shift @{ $self->[BUFFER] }) {
    warn " >> '$raw_line'\n" if $self->[DEBUG];
    if (my $event = _parseline($raw_line)) {
      push @events, $event;
    } else {
      warn "Received malformed IRC input: $raw_line\n";
    }
  }
  \@events
}


use bytes;


sub put {
  my ($self, $events) = @_;
  my $raw_lines = [];

  for my $event (@$events) {

    if ( ref $event eq 'HASH' ) {
      my $raw_line;

      if ( $event->{tags} && (my @tags = %{ $event->{tags} }) ) {
          $raw_line .= '@';
          while (my ($thistag, $thisval) = splice @tags, 0, 2) {
            $raw_line .= $thistag . ( defined $thisval ? '='.$thisval : '' );
            $raw_line .= ';' if @tags;
          }
          $raw_line .= ' ';
      }

      $raw_line .= ':' . $event->{prefix} . ' ' if $event->{prefix};
      $raw_line .= $event->{command};

      if ( $event->{params} && (my @params = @{ $event->{params} }) ) {
          $raw_line .= ' ';
          my $param = shift @params;
          while (@params) {
            $raw_line .= $param . ' ';
            $param = shift @params;
          }
          $raw_line .= ':'
            if (index($param, SPCHR) != -1)
            or (
              defined $event->{colonify} ?
              $event->{colonify} : $self->[COLONIFY]
            );
          $raw_line .= $param;
      }

      push @$raw_lines, $raw_line;
      warn " << '$raw_line'\n" if $self->[DEBUG];
    } else {
      carp "($self) non-HASH passed to put(): '$event'";
      push @$raw_lines, $event if ref $event eq 'SCALAR';
    }

  }

  $raw_lines
}


sub _parseline {
  my $raw_line = $_[0];
  my %event = ( raw_line => $raw_line );
  my $pos = 0;
  no warnings 'substr';

  ## We cheat a little; the spec is fuzzy when it comes to CR, LF, and NUL
  ## bytes. Theoretically they're not allowed inside messages, but
  ## that's really an implementation detail (and the spec agrees).
  ## We just stick to SPCHR (\x20) here.

  if ( substr($raw_line, 0, 1) eq '@' ) {
    return unless (my $nextsp = index($raw_line, SPCHR)) > 0;
    # Tag parser cheats; split takes a pattern:
    for my $tag_pair 
      ( split /;/, substr $raw_line, 1, ($nextsp - 1) ) {
          my ($thistag, $thisval) = split /=/, $tag_pair;
          $event{tags}->{$thistag} = $thisval
    }
    $pos = $nextsp + 1;
  }

  $pos++ while substr($raw_line, $pos, 1) eq SPCHR;

  if ( substr($raw_line, $pos, 1) eq ':' ) {
    my $nextsp;
    ($nextsp = index $raw_line, SPCHR, $pos) > 0 and length(
        $event{prefix} = substr $raw_line, ($pos + 1), ($nextsp - $pos - 1)
    ) or return;
    $pos = $nextsp + 1;
    $pos++ while substr($raw_line, $pos, 1) eq SPCHR;
  }

  my $nextsp_maybe;
  if (($nextsp_maybe = index $raw_line, SPCHR, $pos) == -1) {
    # No more spaces; do we have anything..?
    my $cmd = substr $raw_line, $pos;
    $event{command} = uc( length $cmd ? $cmd : return );
    return \%event
  }

  $event{command} = uc( 
    substr($raw_line, $pos, ($nextsp_maybe - $pos) )
  );
  $pos = $nextsp_maybe + 1;

  $pos++ while substr($raw_line, $pos, 1) eq SPCHR;

  my $maxlen = length $raw_line;
  PARAM: while ( $pos < $maxlen ) {
    if (substr($raw_line, $pos, 1) eq ':') {
      push @{ $event{params} }, substr $raw_line, ($pos + 1);
      last PARAM
    }
    if ((my $nextsp = index $raw_line, SPCHR, $pos) == -1) {
      push @{ $event{params} }, substr $raw_line, $pos;
      last PARAM
    } else {
      push @{ $event{params} }, substr $raw_line, $pos, ($nextsp - $pos);
      $pos = $nextsp + 1;
      $pos++ while substr($raw_line, $pos, 1) eq SPCHR;
      next PARAM
    }
  }

  \%event
}


no bytes;


print
  qq[<mst> let's try this again -without- the part where we beat you to],
  qq[ death with a six foot plush toy of sexual harassment panda\n ]
unless caller; 1;


=pod

=head1 NAME

POE::Filter::IRCv3 - IRCv3.2 parser without regular expressions

=head1 SYNOPSIS

  my $filter = POE::Filter::IRCv3->new(colonify => 1);

  # Raw lines parsed to hashes:
  my $array_of_refs  = $filter->get( 
    [ 
      ':prefix COMMAND foo :bar',
      '@foo=bar;baz :prefix COMMAND foo :bar',
    ]
  );

  # Hashes deparsed to raw lines:
  my $array_of_lines = $filter->put( 
    [
      {
        prefix  => 'prefix',
        command => 'COMMAND',
        params  => [
          'foo',
          'bar'
        ],
      },
      {
        prefix  => 'prefix',
        command => 'COMMAND',
        params  => [
          'foo',
          'bar'
        ],
        tags => {
          foo => 'bar',
          baz => undef,
        },
      },
    ] 
  );


  # Stacked with a line filter, suitable for Wheel usage, etc:
  my $ircd = POE::Filter::IRCv3->new(colonify => 1);
  my $line = POE::Filter::Line->new(
    InputRegexp   => '\015?\012',
    OutputLiteral => "\015\012",
  );
  my $stacked = POE::Filter::Stackable->new(
    Filters => [ $line, $ircd ],
  );

=head1 DESCRIPTION

A L<POE::Filter> for IRC traffic with support for IRCv3.2 message tags.

Does not rely on regular expressions for parsing, unlike many of its
counterparts; benchmarks show this approach is slightly faster on most strings.

Like any proper L<POE::Filter>, there are no POE-specific bits involved here
-- the filter can be used stand-alone to parse lines of IRC traffic (also see
L<IRC::Toolkit::Parser>). 

In fact, you do not need L<POE> installed -- if L<POE::Filter> is not
available, it is left out of C<@ISA> and the filter will continue working
normally.

=head2 new

Construct a new Filter; if the B<colonify> option is true, 
the last parameter will always have a colon prepended.
(This setting can also be retrieved or changed on-the-fly by calling 
B<colonify> as a method, or changed for specific events by passing a 
B<colonify> option via events passed to L</put>.)

=head2 get_one_start, get_one, get_pending

Implement the interface described in L<POE::Filter>.

See L</get>.

=head2 get

  my $events = $filter->get( [ $line, $another, ... ] );
  for my $event (@$events) {
    my $cmd = $event->{command};
    ## See below for other keys available
  }

Takes an ARRAY of raw lines and returns an ARRAY of HASH-type references with 
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

Takes an ARRAY of HASH-type references matching those described in L</get> 
(documented above) and returns an ARRAY of raw IRC-formatted lines.

=head3 colonify

In addition to the keys described in L</get>, the B<colonify> option can be 
specified for specific events. This controls whether or not the last 
parameter will be colon-prefixed even if it is a single word. (Yes, IRC is 
woefully inconsistent ...)

Specify as part of the event hash:

  $filter->put([ { %event, colonify => 1 } ]);

=head2 clone

Copy the filter object (with a cleared buffer).

=head2 debug

Turn on/off debug output, which will display every input/output line (and
possibly other data in the future).

This is enabled by default at construction time if the environment variable
C<POE_FILTER_IRC_DEBUG> is a true value.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

Licensed under the same terms as Perl.

Original implementations were derived from L<POE::Filter::IRCD>, 
which is copyright Chris Williams and Jonathan Steinert. This codebase has
diverged significantly.

Major thanks to the C<#ircv3> crew on irc.atheme.org, especially C<Aerdan> and
C<grawity>, for various bits of inspiration.

=head1 SEE ALSO

L<IRC::Message::Object>

L<POE::Filter>

L<POE::Filter::IRCD>

L<POE::Filter::Line>

L<POE::Filter::Stackable>

L<IRC::Toolkit>

=cut
