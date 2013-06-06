use Test::More tests => 14;
use strict; use warnings qw/FATAL all/;

BEGIN {
 use_ok 'POE::Filter::IRCv3';
}
my $filter = POE::Filter::IRCv3->new;

isa_ok( $filter, 'POE::Filter' );

my $one = ':test!me@test.ing PRIVMSG #Test :This is a test';

for my $event (@{ $filter->get([ $one ]) }) {
  cmp_ok( $event->{prefix}, 'eq', 'test!me@test.ing', 'prefix looks ok' );
  cmp_ok( $event->{command}, 'eq', 'PRIVMSG', 'command looks ok' );

  cmp_ok( $event->{params}->[0], 'eq', '#Test', 'param 0 looks ok' );
  cmp_ok( $event->{params}->[1], 'eq', 'This is a test', 'param 1 looks ok' );

  for my $parsed (@{ $filter->put([ $event ]) }) {
    cmp_ok($parsed, 'eq', $one, 'put() looks ok' );
  }
}

my $two = 'PRIVMSG #testing :No-prefix test';
for my $event (@{ $filter->get([ $two ]) }) {
  ok( !$event->{prefix}, 'Lack of prefix looks ok' );
  cmp_ok( $event->{command}, 'eq', 'PRIVMSG', 'command looks ok 2' );

  cmp_ok( $event->{params}->[0], 'eq', '#testing', 'param 0 looks ok 2' );
  cmp_ok( $event->{params}->[1], 'eq', 'No-prefix test', 'param 1 looks ok 2' );

  for my $parsed (@{ $filter->put([ $event ]) }) {
    cmp_ok($parsed, 'eq', $two, 'put() looks ok 2' );
  }
}

my $spaces = ':test PRIVMSG foo :A string   with spaces';
for my $event (@{ $filter->get([ $spaces ]) } ) {
  cmp_ok( $event->{params}->[1], 'eq', 'A string   with spaces' );
}

{
  my @warned;
  local $SIG{__WARN__} = sub {
    push @warned, @_;
  };
  $filter->get([ ':foo' ]);
  ok( @warned == 1, 'bad string warned' )
    or diag explain \@warned;
}
