package TestFilterHelpers;
use strict; use warnings FATAL => 'all';

use Carp 'croak';
require Scalar::Util;

use Test::Deep::NoTest qw/
  cmp_deeply

  cmp_details
  deep_diag
/;

use base 'Exporter';
our @EXPORT = qw/
  cmp_deeply

  get_struct_ok

  get_command_ok
  get_prefix_ok
  get_params_ok
  get_rawline_ok
  get_tags_ok

  put_ok
/;

my $Test = Test::Builder->new;
sub import {
  my $self = shift;
  if (@_) {
    my $pkg = caller;
    $Test->exported_to( $pkg );
    $Test->plan( @_ );
  }
  $self->export_to_level( 1, $self, $_ ) for @EXPORT;
}


sub _looks_ok {
  my ($got, $expected, $name) = @_;

  my ($ok, $stack) = cmp_details($got, $expected);

  unless ( $Test->ok($ok, $name) && return 1 ) {
    $Test->diag( deep_diag($stack) )
  }
  
  return
}


sub put_ok {
  my ($filter, $line, $ref, $name) = @_;

  unless (Scalar::Util::blessed $filter) {
    croak "put_ok expected blessed filter obj"
  }

  unless (defined $line && !ref($line) && ref $ref eq 'HASH') {
    croak "put_ok expected a line to compare and a HASH to process"
  }

  my $arr = $filter->put([ $ref ]);
  croak "filter did not return ARRAY for $ref"
    unless ref $arr eq 'ARRAY';
  croak "filter did not return line for $ref"
    unless defined $arr->[0];

  $name = 'line looks ok' unless defined $name;
  _looks_ok( $arr, [ $line ], $name )
}


sub get_struct_ok {
  my ($filter, $line, $ref, $name) = @_;

  unless (Scalar::Util::blessed $filter) {
    croak "get_struct_ok expected blessed filter obj"
  }

  unless (defined $line && ref $ref eq 'HASH') {
    croak "get_struct_ok expected a line to process and HASH to compare"      
  }

  $ref->{raw_line} = $line unless exists $ref->{raw_line};

  my $arr = $filter->get([ $line ]);

  croak "filter did not return ARRAY for $line"
    unless ref $arr eq 'ARRAY';

  $name = 'struct looks ok' unless defined $name;
  _looks_ok( $arr, [$ref], $name )
}


sub get_command_ok {
  my ($filter, $line, $cmd, $name) = @_;

  unless (Scalar::Util::blessed $filter) {
    croak "get_command_ok expected blessed filter obj"
  }

  unless (defined $line && defined $cmd) {
    croak "get_command_ok expected a line to process and command to compare"
  }

  my $arr = $filter->get([ $line ]);

  croak "filter did not return ARRAY for $line"
    unless ref $arr eq 'ARRAY';
  croak "filter did not return event for $line"
    unless ref $arr->[0] eq 'HASH';

  $name = 'command looks ok' unless defined $name;
  _looks_ok( $arr->[0]->{command}, $cmd, $name )
}

sub get_prefix_ok {
  my ($filter, $line, $pfx, $name) = @_;

  unless (Scalar::Util::blessed $filter) {
    croak "get_prefix_ok expected blessed filter obj"
  }

  unless (defined $line && defined $pfx) {
    croak "get_prefix_ok expected a line to process and prefix to compare"
  }

  my $arr = $filter->get([ $line ]);
  croak "filter did not return ARRAY for $line"
    unless ref $arr eq 'ARRAY';
  croak "filter did not return event for $line"
    unless ref $arr->[0] eq 'HASH';

  $name = 'prefix looks ok' unless defined $name;
  _looks_ok( $arr->[0]->{prefix}, $pfx, $name )
}

sub get_params_ok {
  my ($filter, $line, $pref, $name) = @_;

  unless (Scalar::Util::blessed $filter) {
    croak "get_params_ok expected blessed filter obj"
  }

  # pref => undef is legit
  unless (defined $line) {
    croak "get_params_ok expected a line to process and params to compare"
  }

  my $arr = $filter->get([ $line ]);
  croak "filter did not return ARRAY for $line"
    unless ref $arr eq 'ARRAY';
  croak "filter did not return event for $line"
    unless ref $arr->[0] eq 'HASH';

  $name = 'params look ok' unless defined $name;
  _looks_ok( $arr->[0]->{params}, $pref, $name )
}

sub get_rawline_ok {
  my ($filter, $line, $name) = @_;
  
  unless (Scalar::Util::blessed $filter) {
    croak "get_rawline_ok expected blessed filter obj"
  }

  unless (defined $line) {
    croak "get_rawline_ok expected a line to process"
  }

  my $arr = $filter->get([ $line ]);
  croak "filter did not return ARRAY for $line"
    unless ref $arr eq 'ARRAY';
  croak "filter did not return event for $line"
    unless ref $arr->[0] eq 'HASH';

  $name = 'raw_line looks ok' unless defined $name;
  _looks_ok( $arr->[0]->{raw_line}, $line, $name )
}

sub get_tags_ok {
  my ($filter, $line, $tags, $name) = @_;

  unless (Scalar::Util::blessed $filter) {
    croak "get_tags_ok expected blessed filter obj"
  }

  unless (defined $line && ref $tags eq 'HASH') {
    croak "get_tags_ok expected a line to process and a tags HASH to compare"
  }

  my $arr = $filter->get([ $line ]);
  croak "filter did not return ARRAY for $line"
    unless ref $arr eq 'ARRAY';
  croak "filter did not return event for $line"
    unless ref $arr->[0] eq 'HASH';

  $name = 'tags look ok' unless defined $name;
  _looks_ok( $arr->[0]->{tags}, $tags, $name )
}


1;
