use Test::More;
use strict; use warnings FATAL => 'all';

use lib 't/inc';
use TestFilterHelpers;

use POE::Filter::IRCv3;

my $filter = POE::Filter::IRCv3->new;

my $line;

# NUL, LF, SPACE, BELL
$line = '@foo=bar\0\nbaz\squ\aux things';
## FIXME full get tests
get_tags_ok $filter, $line =>
  +{
    foo => "bar\0\nbaz qu\aux",
  },
  'NUL, LF, SPACE, BELL escape ok';

my $ev  = $filter->get([$line]);
my $raw = $filter->put([@$ev]);
ok index($raw->[0], 'bar\0\nbaz\squ\aux') > -1,
  'roundtripped NUL, LF, SPACE, BELL'
    or diag explain [ $ev, $raw ];


# SEMICOLON, BACKSLASH, CR
$line = "\@foo=bar\\:\\\\baz\\rquux stuff";

# FIXME full get tests
get_tags_ok $filter, $line =>
  +{
    foo => "bar;\\baz\rquux",
  },
  'SEMICOLON, BACKSLASH, CR escape ok';

$ev  = $filter->get([$line]);
$raw = $filter->put([ @$ev ]);
ok index($raw->[0], 'bar\:\\baz\rquux') > -1,
  'roundtripped SEMICOLON, BACKSLASH, CR'
    or diag explain [ $ev, $raw ];

done_testing
