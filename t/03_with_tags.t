use Test::More tests => 9;
use strict; use warnings qw/FATAL all/;

use POE::Filter::IRCv3;
my $filter = POE::Filter::IRCv3->new;

isa_ok( $filter, 'POE::Filter' );

my $str = '@intent=ACTION;znc.in/extension=value;foobar'.
          ' :test!me@test.ing PRIVMSG #Test :This is a test';

for my $event (@{ $filter->get([ $str ]) }) {
  is_deeply( $event->{tags},
    {
      intent => 'ACTION',
      'znc.in/extension' => 'value',
      foobar => undef,
    },
    'tags look ok'
  );
  cmp_ok( $event->{prefix}, 'eq', 'test!me@test.ing', 'prefix looks ok' );
  cmp_ok( $event->{command}, 'eq', 'PRIVMSG', 'command looks ok' );
  cmp_ok( $event->{params}->[0], 'eq', '#Test', 'param 0 looks ok' );
  cmp_ok( $event->{params}->[1], 'eq', 'This is a test', 'param 1 looks ok' );
  for my $parsed (@{ $filter->put([ $event ]) }) {
    cmp_ok($parsed, '=~', qr/intent=ACTION/, 'parsed has intent=ACTION');
    cmp_ok($parsed, '=~', qr/znc\.in\/extension=value/, 
      'parsed has vendor ext' 
    );
    cmp_ok($parsed, '=~', qr/foobar/, 'parsed has arbitrary valueless tag' );
  }
}
