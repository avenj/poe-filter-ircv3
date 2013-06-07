use strictures 1;
use Benchmark ':all';

require POE::Filter::IRCD;
require POE::Filter::IRCv3;
my $old = POE::Filter::IRCD->new;
my $new = POE::Filter::IRCv3->new;

my $basic = ':test!me@test.ing PRIVMSG #Test :This is a test';

my $tests = +{
  old => sub {
    my $ev_one = $old->get([$basic]);
    $old->put([ @$ev_one ]);
    my $ev_two = $old->get([':foo bar']);
    $old->put([ @$ev_two ]);
  },

  new => sub {
    my $ev_one = $new->get([$basic]);
    $new->put([ @$ev_one ]);
    my $ev_two = $new->get([':foo bar']);
    $new->put([ @$ev_two ]);
  },
};

cmpthese( 100_000, $tests );
timethese( 100_000, $tests );
