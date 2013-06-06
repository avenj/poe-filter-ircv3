package POE::Filter::IRCv3;

use strictures 1;
use Carp;

use parent 'POE::Filter';

=pod

=for Pod::Coverage COLONIFY DEBUG BUFFER

=cut

sub COLONIFY () { 0 }
sub DEBUG    () { 1 }
sub BUFFER   () { 2 }


sub new {
  my ($class, %params) = @_;
  $params{uc $_} = $params{$_} for keys %params;

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

sub _parseline {
  my ($raw_line) = @_;
  my @input = split //, ( $raw_line || return );
  my %event = ( raw_line => $raw_line );

  if ( $input[0] eq '@' ) {
    my $space;
    for my $i ( 1 .. $#input ) {
      if ($input[$i] eq "\x20") {
        $space = $i - 1;
        last
      }
    }
    my $tag_str = join '', @input[1 ..  ( $space || return )];
    for my $tag_pair (split /;/, $tag_str) {
      my ($thistag, $thisval) = split /=/, $tag_pair;
      $event{tags}->{$thistag} = $thisval
    }
    
    @input = @input[ ($space + 1) .. $#input ];
  }

  while ( $input[0] eq "\x20" ) {
    shift @input
  }

  if ( $input[0] eq ':' ) {
    my $space;
    for my $i ( 1 .. $#input ) {
      if ($input[$i] eq "\x20") {
        $space = $i - 1;
        last
      }
    }
    $event{prefix} = join '', @input[1 .. ( $space || return )];

    @input = @input[ ($space + 1) .. $#input ];

    while ( $input[0] eq "\x20" ) {
      shift @input
    }
  }

  { my $space;
    for my $i ( 1 .. $#input ) {
      if ($input[$i] eq "\x20") {
        $space = $i - 1;
        last
      }
    }
    $event{command} = uc( join '', @input[0 .. ( $space || return)] );

    @input = @input[ ($space + 1) .. $#input ];
  }

  while ( $input[0] eq "\x20" ) {
    shift @input
  }

  my $pstr;
  PARAMCHR: while (defined (my $chr = shift @input)) {
    if ($chr eq ':') {
      push @{ $event{params} }, join '', @input[0 .. $#input];
      last PARAMCHR
    }
    if ($chr eq "\x20") {
      if (defined $pstr) {
        push @{ $event{params} }, $pstr;
        undef $pstr
      }
      next PARAMCHR
    }
    $pstr .= $chr
  }
  push @{ $event{params} }, $pstr if defined $pstr;

  \%event
}

sub get_one {
  my ($self) = @_;
  my @events;

  if (my $raw_line = shift @{ $self->[BUFFER] }) {
    warn "-> $raw_line \n" if $self->[DEBUG];

    if (my $event = _parseline($raw_line)) {
      push @events, $event;
    } else {
      carp "Received malformed IRC input: $raw_line";
    }
  }

  \@events
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

      $raw_line .= ':' . $event->{prefix} . ' ' if $event->{prefix};
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

POE::Filter::IRCv3 - POE IRC filter IRCv3.2 message tags

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

A L<POE::Filter> for IRC traffic.

Adds support for IRCv3.2 message tags.

Does not rely on regular expressions for parsing, unlike many of its
counterparts.

Like any proper L<POE::Filter>, there are no POE-specific bits involved 
here; the filter can be used stand-alone to parse IRC traffic (see
L<IRC::Toolkit::Parser>).

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

Turn on/off debug output.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

Originally derived from L<POE::Filter::IRCD>, which is copyright Chris
Williams and Jonathan Steinert; heavily modified since that time, such that
little original code remains, but I stand on the shoulders of giants ;-)

Licensed under the same terms as Perl.

=head1 SEE ALSO

L<POE::Filter>

L<POE::Filter::IRCD>

L<POE::Filter::Line>

L<POE::Filter::Stackable>

L<IRC::Toolkit>

=cut
