use Test::More tests => 3;
use strict; use warnings qw/FATAL all/;

use POE::Filter::IRCv3;
my $filter = POE::Filter::IRCv3->new(colonify => 1);

my $str = ':test!me@test.ing PRIVMSG #Test :Single';

for my $event (@{ $filter->get([ $str ]) }) {
  for my $parsed (@{ $filter->put([ $event ]) }) {
    cmp_ok($parsed, 'eq', $str, 'put() looks ok' );
  }
}

my $newfilt = $filter->clone;
isa_ok($newfilt, 'POE::Filter::IRCv3');

for my $event (@{ $newfilt->get([ $str ]) }) {
  for my $parsed (@{ $filter->put([ $event ]) }) {
    cmp_ok($parsed, 'eq', $str, 'cloned put() looks ok' );
  }
}
