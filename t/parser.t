use strict; use warnings FATAL => 'all';
use lib 't/inc';
use Test::More;
use TestFilterHelpers;

BEGIN { use_ok('POE::Filter::IRCv3') }

our $filter = new_ok( 'POE::Filter::IRCv3' => [ colonify => 1 ] );

# clone
{ my $clone = $filter->clone;
  isa_ok $clone, ref $filter;
  ok $clone->colonify, 
    'cloned obj preserved colonify => 1';
}

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
    my $ev = get_ok $filter, $line =>
      +{
          raw_line => $line,
          command  => 'FOO',
          prefix   => 'test',
      },
      'simple prefix and cmd get() with trailing space ok' ;

    put_ok $filter, ":test FOO" => $ev,
      'simple prefix and cmd put() with trailing space ok' ;
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
{ my $line = ":test FOO\tBAR baz quux :A string";
  
    my $ev = get_ok $filter, $line =>
      +{
          raw_line => $line,
          command  => "FOO\tBAR",
          params   => [
            'baz', 'quux', 'A string',
          ],
          prefix   => 'test',
      },
      'command containing tabs get() ok' ;

    put_ok $filter, $line => $ev,
      'command containing tabs put() ok' ;
}

# Middle params containing tabs
{ my $line = ":test JOIN #foo\tbar :baz";

    my $ev = get_ok $filter, $line =>
      +{
          raw_line => $line,
          command  => 'JOIN',
          params   => [
            "#foo\tbar", 'baz'
          ],
          prefix   => 'test',
      },
      'middle params containing tabs get() ok' ;

    put_ok $filter, $line => $ev,
      'middle params containing tabs put() ok' ;
}

# Middle params containing colons
{ my $line = ':test PRIVMSG #fo:oo :This is a test';
  
    my $ev = get_ok $filter, $line =>
      +{
          raw_line => $line,
          command  => 'PRIVMSG',
          params   => [
            '#fo:oo', 'This is a test'
          ],
          prefix   => 'test',
      },
      'middle params containing colons get() ok' ;

    put_ok $filter, $line => $ev,
      'middle params containing colons put() ok' ;
}

# No prefix, command, one middle param, trailing params
{ my $line = 'PRIVMSG #foo :No prefix test';

    my $ev = get_ok $filter, $line =>
      +{
          raw_line => $line,
          command  => 'PRIVMSG',
          params   => [
            '#foo', 'No prefix test'
          ],
      },
      'command with params and no prefix get() ok' ;

    put_ok $filter, $line => $ev,
      'command with params and no prefix put() ok' ;
}

# Prefix, command, one middle param, trailing params with extra spaces
{ my $line = ':test PRIVMSG foo :A string   with spaces   ';

    my $ev = get_ok $filter, $line =>
      +{
          raw_line => $line,
          command  => 'PRIVMSG',
          params   => [
            'foo', 'A string   with spaces   '
          ],
          prefix   => 'test',
      },
      'trailing spaces in string param get() ok' ;

    put_ok $filter, $line => $ev,
      'trailing spaces in string param put() ok' ;
}

# Extraneous spaces between prefix/command/params
{ my $line = ':test   PRIVMSG   foo   :bar';
  
    my $ev = get_ok $filter, $line =>
      +{
          raw_line => $line,
          command  => 'PRIVMSG',
          params   => [
            'foo', 'bar'
          ],
          prefix   => 'test',
      },
      'extraneous space in command/params get() ok';
  
    put_ok $filter, ":test PRIVMSG foo :bar" => $ev,
      'extraneous space in command/params put() ok';
}

# Tags, no prefix
{ my $line = '@foo=bar;znc.in/ext=val;baz'
            .' PRIVMSG #chan :A string';
  
    get_command_ok $filter, $line => 'PRIVMSG',
      'tags without prefix command ok';

    get_params_ok $filter, $line =>
      [
        '#chan', 'A string'
      ],
      'tags without prefix params ok';

    get_prefix_ok $filter, $line => undef,
      'tags without prefix no prefix ok';

    get_tags_ok $filter, $line =>
      +{
          foo          => 'bar',
          'znc.in/ext' => 'val',
          'baz'        => undef,
      },
      'tags without prefix tags ok';


    my $ev  = $filter->get([ $line ]);
    my $raw = $filter->put([ @$ev ]);

    cmp_ok $raw->[0], '=~', qr/foo=bar/,
      'tags without prefix put() has foo=bar ok';

    cmp_ok $raw->[0], '=~', qr/znc\.in\/ext=val/,
      'tags without prefix put() has vendor ext ok';

    cmp_ok $raw->[0], '=~', qr/baz[; ]/,
      'tags without prefix put() has valueless tag ok';

    my $second = $filter->get([ @$raw ]);
    delete $ev->[0]->{raw_line}; delete $second->[0]->{raw_line};
    is_deeply $second, $ev, 'round-tripped tags without prefix';
}

# Tags with prefix
{ my $line = '@foo=bar;znc.in/ext=val;baz'
            .' :test PRIVMSG #chan :A string';

    get_prefix_ok $filter, $line => 'test',
      'tags with prefix prefix ok';

    get_command_ok $filter, $line => 'PRIVMSG',
      'tags with prefix command ok';

    get_params_ok $filter, $line =>
      [
        '#chan', 'A string'
      ],
      'tags with prefix params ok';

    get_tags_ok $filter, $line =>
     +{
          foo          => 'bar',
          'znc.in/ext' => 'val',
          baz          => undef,
      },
      'tags with prefix tags ok';
    
    my $ev  = $filter->get([ $line ]);
    my $raw = $filter->put([ @$ev ]);

    cmp_ok $raw->[0], '=~', qr/foo=bar/,
      'tags with prefix put() has foo=bar ok';

    cmp_ok $raw->[0], '=~', qr/znc\.in\/ext=val/,
      'tags with prefix put() has vendor ext ok';

    cmp_ok $raw->[0], '=~', qr/baz[; ]/,
      'tags with prefix put() has valueless tag ok';

    my $second = $filter->get([ @$raw ]);
    delete $ev->[0]->{raw_line}; delete $second->[0]->{raw_line};
    is_deeply $second, $ev, 'round-tripped tags with prefix';
}

# Params containing arbitrary bytes
{ use bytes;
  my $line = ":foo PRIVMSG #f\x{df}\x{de}oo\707\0";

  get_prefix_ok $filter, $line => 'foo',
    'arbitrary bytes prefix ok';

  get_command_ok $filter, $line => 'PRIVMSG',
    'arbitrary bytes command ok';

  my $ev = $filter->get([ $line ])->[0];

  ok @{$ev->{params}} == 1, 
    'arbitrary bytes param count ok';

  ok $ev->{params}->[0] eq "#f\x{df}\x{de}oo\707\0",
    'arbitrary bytes params ok';

  $ev->{colonify} = 0;
  ok $filter->put([ $ev ])->[0] eq $line, 
    'bytes round-tripped ok';
}

# 'colonify =>' behavior
{ local $filter = POE::Filter::IRCv3->new(colonify => 1);
  my $str = ':test FOO :bar';
  my $ev  = $filter->get([ $str ]);
  my $par = $filter->put([ @$ev ]);
  cmp_ok $par->[0], 'eq', $str,
    'colonify => 1 round-trip ok';

  $ev->[0]->{colonify} = 0;
  my $wpar = $filter->put([ @$ev ]);
  cmp_ok $wpar->[0], 'eq', ':test FOO bar',
    'per-event colonify => 0 ok';
}
{ local $filter = POE::Filter::IRCv3->new(colonify => 0);
  my $str = 'FOO bar';
  my $ev  = $filter->get([ $str ]);
  my $par = $filter->put([ @$ev ]);
  cmp_ok $par->[0], 'eq', $str,
    'colonify => 0 round-trip ok';

  $ev->[0]->{colonify} = 1;
  my $wpar = $filter->put([ @$ev ]);
  cmp_ok $wpar->[0], 'eq', 'FOO :bar',
    'per-event colonify => 1 ok';

  put_ok $filter, "FOO foo :A string" =>
    +{
        colonify => 0,
        command => 'FOO',
        params  => [ 'foo', 'A string' ],
    },
    'colonified string with spaces';
}

# Bad lines warn
{ my $line = ':foo';
  
  my $warned;
  local $SIG{__WARN__} = sub { ++$warned };

  ok !@{$filter->get([ $line ])}, 
    'line with prefix only returned';
  ok $warned, 
    'line with prefix only warned';
}
{ my $line = '@foo :foo';

  my $warned;
  local $SIG{__WARN__} = sub { ++$warned };

  ok !@{$filter->get([ $line ])}, 
    'line with tags and prefix only returned';
  ok $warned, 
    'line with tags and prefix only warned';
}

done_testing;
