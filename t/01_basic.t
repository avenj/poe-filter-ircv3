use Test::More tests => 20;
use strict; use warnings qw/FATAL all/;

BEGIN {
 use_ok 'POE::Filter::IRCv3';
}
my $filter = POE::Filter::IRCv3->new;

isa_ok( $filter, 'POE::Filter' );

my $simple = ':test foo';
for my $event (@{ $filter->get([ $simple ]) } ) {
  cmp_ok( $event->{command}, 'eq', 'FOO',
    'simple prefix+cmd ok'
  );
}

my $pfix = ':test!me@test.ing PRIVMSG #Test :This is a test';
for my $event (@{ $filter->get([ $pfix ]) }) {
  cmp_ok( $event->{prefix}, 'eq', 'test!me@test.ing', 'prefix looks ok' );
  cmp_ok( $event->{command}, 'eq', 'PRIVMSG', 'command looks ok' );

  cmp_ok( $event->{params}->[0], 'eq', '#Test', 'param 0 looks ok' );
  cmp_ok( $event->{params}->[1], 'eq', 'This is a test', 'param 1 looks ok' );

  for my $parsed (@{ $filter->put([ $event ]) }) {
    cmp_ok($parsed, 'eq', $pfix, 'put() looks ok' );
  }
}

my $nopfx = 'PRIVMSG #testing :No-prefix test';
for my $event (@{ $filter->get([ $nopfx ]) }) {
  ok( !$event->{prefix}, 'Lack of prefix looks ok' );
  cmp_ok( $event->{command}, 'eq', 'PRIVMSG', 'command looks ok 2' );

  cmp_ok( $event->{params}->[0], 'eq', '#testing', 'param 0 looks ok 2' );
  cmp_ok( $event->{params}->[1], 'eq', 'No-prefix test', 'param 1 looks ok 2' );

  for my $parsed (@{ $filter->put([ $event ]) }) {
    cmp_ok($parsed, 'eq', $nopfx, 'put() looks ok 2' );
  }
}

my $spaces = ':test PRIVMSG foo :A string   with spaces  ';
for my $event (@{ $filter->get([ $spaces ]) } ) {
  cmp_ok( $event->{params}->[1], 'eq', 'A string   with spaces  ',
    'string with spaces preserved ok'
  );
}

my $tabs = ":test FOO\tBAR baz quux :A string";
for my $event (@{ $filter->get([ $tabs ]) } ) {
  cmp_ok( $event->{command}, 'eq', "FOO\tBAR", 'command with tabs ok' );
  is_deeply( $event->{params},
    [
      'baz', 'quux', 'A string'
    ],
    'multi params ok'
  );
}


my $exspace = ':test   PRIVMSG  foo :bar';
for my $event (@{ $filter->get([ $exspace ]) }) {
  cmp_ok( $event->{prefix}, 'eq', 'test',
    'prefix with extraneous space ok'
  );
  cmp_ok( $event->{command}, 'eq', 'PRIVMSG', 
    'command with extraneous space ok' 
  );
  is_deeply( $event->{params},
    [
      'foo', 'bar'
    ],
    'params with extraneous space ok'
  );
}



{
  my @warned;
  local $SIG{__WARN__} = sub {
    push @warned, @_;
  };
  $filter->get([ ':foo' ]);
  ok( ( @warned == 1 && $warned[0] =~ /malformed/ ), 
    'bad string warned' ) or diag explain \@warned;
}
