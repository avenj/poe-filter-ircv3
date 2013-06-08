use strict; use warnings FATAL => 'all';
use lib 't/inc';
use Test::More;
use TestFilterHelpers;

BEGIN { use_ok('POE::Filter::IRCv3') }

my $filter = new_ok( 'POE::Filter::IRCv3' );

# Simple prefix + command
{ my $simple = ':test foo';
  get_struct_ok $filter, $simple =>
    +{
        raw_line => $simple,
        command  => 'FOO',
        prefix   => 'test',
    },
    'simple prefix and cmd get() looks ok';

  put_ok $filter, $simple => 
    +{ command => 'foo', prefix => 'test' },
    'simple prefix and cmd put() looks ok'
}

done_testing;
