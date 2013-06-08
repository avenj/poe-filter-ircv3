use Test::More;
use strict; use warnings FATAL => 'all';

BEGIN { use_ok('POE::Filter::IRCv3') }

my $filter = new_ok( 'POE::Filter::IRCv3' );

{ my $simple = ':test foo'; 
  my $ev = $filter->get([ $simple ]);
  is_deeply( $ev,
    [ 
      +{
        prefix  => 'test',
        command => 'FOO',
        raw_line => $simple,
      } 
    ],
    'simple prefix and command get() ok'
  );

  $filter->get_one_start([ $simple ]);
  my $started = $filter->get_one;
  is_deeply(
    $started,
    $ev,
    'get_one_start/get_one ok'
  );
}

{ my $trailing = ':test foo  ';
  my $ev = $filter->get([ $trailing ]);
  is_deeply( $ev,
    [
      +{
        prefix  => 'test',
        command => 'FOO',
        raw_line => $trailing,
      }
    ],
    'simple prefix and cmd with trailing space ok'
  ) or diag explain $ev;
}

{ my $pfix = ':test!me@test.ing PRIVMSG #Test :This is a test';
  my $ev = $filter->get([ $pfix ]);
  is_deeply( $ev,
    [
      +{
        prefix  => 'test!me@test.ing',
        command => 'PRIVMSG',
        params  => [
          '#Test',
          'This is a test'
        ],
        raw_line => $pfix,
      },
    ],
    'prefixed cmd with string looks ok'
  );

  my $parsed = $filter->put([ $ev->[0] ]);
  cmp_ok( $parsed->[0], 'eq', $pfix, 
    'put() with prefix looks ok' 
  );
}

{ my $nopfx = 'PRIVMSG #testing :No-prefix test';
  my $ev = $filter->get([ $nopfx ]);
  is_deeply( $ev,
    [
      +{
        command => 'PRIVMSG',
        params  => [
          '#testing',
          'No-prefix test'
        ],
        raw_line => $nopfx,
      },
    ],
    'non-prefixed cmd with string looks ok'
  );
  
  my $parsed = $filter->put([ $ev->[0] ]);
  cmp_ok( $parsed->[0], 'eq', $nopfx,
    'put() without prefix looks ok'
  );
}

{ my $spaces = ':test PRIVMSG foo :A string   with spaces  ';
  my $ev = $filter->get([ $spaces ]);
  is_deeply( $ev,
    [
      +{
        prefix  => 'test',
        command => 'PRIVMSG',
        params  => [
          'foo',
          'A string   with spaces  ',
        ],
        raw_line => $spaces,
      },
    ],
    'string with spaces preserved ok'
  );

  my $parsed = $filter->put([ $ev->[0] ]);
  cmp_ok( $parsed->[0], 'eq', $spaces,
    'put() with spaces preserved ok'
  );
}

{ my $tabs = ":test foo\tbar baz quux :A string";
  my $ev = $filter->get([ $tabs ]);
  is_deeply( $ev,
    [
      +{
        prefix  => 'test',
        command => "FOO\tBAR",
        params  => [
          'baz', 'quux', 'A string'
        ],
        raw_line => $tabs,
      },
    ],
    'string with tabs preserved ok'
  );
}

{ my $exspace = ':test   PRIVMSG   foo :bar';
  my $ev = $filter->get([ $exspace ]);
  is_deeply( $ev,
    [
      +{
        prefix  => 'test',
        command => 'PRIVMSG',
        params  => [
          'foo', 'bar'
        ],
        raw_line => $exspace,
      }
    ],
    'string with extraneous spaces ok'
  );
}

{ my $col = POE::Filter::IRCv3->new(colonify => 1);
  isa_ok( $col, 'POE::Filter', 'colonifying obj' );

  my $str = ':test FOO :bar';
  my $ev = $col->get([ $str ]);
  my $parsed = $col->put([ $ev->[0] ]);
  cmp_ok( $parsed->[0], 'eq', $str,
    'colonifying put() looks ok'
  );

  my $withsp = $col->put([
    +{
       colonify => 0,

       command => 'FOO',
       params  => [
         'foo',
         'A string'
       ],
     }
  ]);
  cmp_ok( $withsp->[0], 'eq', 'FOO foo :A string',
    'colonified string with spaces'
  );

  my $withoutsp = $col->put([
      +{
        colonify => 0,

        command => 'FOO',
        params  => [
          'foo',
        ],
      }
  ]);
  cmp_ok( $withoutsp->[0], 'eq', 'FOO foo',
    'skipped colonify ok'
  );    

  my $cloned = $col->clone;
  isa_ok( $cloned, 'POE::Filter::IRCv3', 'cloned obj' );

  my $c_ev  = $cloned->get([ $str ]);
  my $c_par = $cloned->put([ $c_ev->[0] ]);
  cmp_ok( $c_par->[0], 'eq', $str,
    'cloned put() looks ok'
  );
}

{ my $with_tags = '@intent=ACTION;znc.in/extension=value;foobar'
                . ' :test!me@test.ing PRIVMSG #Test :This is a test';

  my $ev = $filter->get([ $with_tags ]);
  is_deeply( $ev,
    [
      +{
        prefix  => 'test!me@test.ing',
        command => 'PRIVMSG',
        params  => [
          '#Test',
          'This is a test'
        ],
        tags    => {
          intent  => 'ACTION',
          foobar  => undef,
          'znc.in/extension' => 'value',
        },
        raw_line => $with_tags,
      },
    ],
    'get() with tags looks ok'
  );

  my $parsed = $filter->put([ $ev->[0] ]);

  cmp_ok( $parsed->[0], '=~', qr/intent=ACTION/, 
    'parsed has intent=ACTION'
  );

  cmp_ok($parsed->[0], '=~', qr/znc\.in\/extension=value/,
    'parsed has vendor ext'
  );

  cmp_ok($parsed->[0], '=~', qr/foobar/, 
    'parsed has arbitrary valueless tag' 
  );
}

{ 
  use bytes;
  my $with_b = ":foo PRIVMSG #f\x{df}\x{de}oo\707\0";
  my $ev = $filter->get([ $with_b ])->[0];

  cmp_ok( $ev->{prefix}, 'eq', 'foo', 
    'bytes get() prefix ok' 
  );
  cmp_ok( $ev->{command}, 'eq', 'PRIVMSG', 
    'bytes get() command ok' 
  );
  ok( $ev->{params}->[0] eq "#f\x{df}\x{de}oo\707\0", 
    'bytes get() params ok' 
  );

  $ev->{colonify} = 0;
  ok( $filter->put([ $ev ])->[0] eq $with_b,
    "bytes round-tripped ok"
  );
}

done_testing;
