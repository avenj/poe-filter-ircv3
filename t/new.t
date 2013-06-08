use strict; use warnings FATAL => 'all';
use lib 't/inc';
use Test::More;
use TestFilterHelpers;

BEGIN { use_ok('POE::Filter::IRCv3') }

my $filter = new_ok( 'POE::Filter::IRCv3' );

# get_one_start/get_one
{ my $line = ':test foo';
    $filter->get_one_start([ ':test foo' ]);
    my $ev = $filter->get_one;
    is_deeply( $ev,
      [
        +{
          prefix   => 'test',
          command  => 'FOO',
          raw_line => $line,
        }
      ],
      'get_one_start/get_one ok'
    );
}


# Simple prefix + command
{ my $line = ':test foo';
    get_ok $filter, $line =>
      +{
          raw_line => $line,
          command  => 'FOO',
          prefix   => 'test',
      },
      'simple prefix and cmd get() looks ok' ;

    put_ok $filter, $line => 
      +{ command => 'foo', prefix => 'test' },
      'simple prefix and cmd put() looks ok' ;
}

# Simple prefix + command with trailing spaces
{ my $line = ':test foo   ';
    get_ok $filter, $line =>
      +{
          raw_line => $line,
          command  => 'FOO',
          prefix   => 'test',
      },
      'simple prefix and cmd get() with trailing space ok' ;
}

# Prefix, command, one middle param, trailing params
{ my $line = ':test!me@test.ing PRIVMSG #Test :This is a test';
    my $ev = get_ok $filter, $line =>
      +{
          raw_line => $line,
          command  => 'PRIVMSG',
          prefix   => 'test!me@test.ing',
          params   => [
            '#Test',
            'This is a test'
          ],
      },
      'prefixed cmd with middle and trailing get() ok' ;

    put_ok $filter, $line => $ev,
      'prefixed cmd with middle and trailing put() ok' ;
}

# Commands containing tabs

# Middle params containing tabs

# Middle params containing colons

# No prefix, command, one middle param, trailing params

# Prefix, command, one middle param, trailing params with extra spaces

# Extraneous spaces between prefix/command/params

# 'colonify =>' behavior

# Tags, no prefix

# Tags with prefix

# Params containing arbitrary bytes

done_testing;
