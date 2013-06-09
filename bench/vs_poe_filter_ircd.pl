use strictures 1;
use Benchmark ':all';

require POE::Filter::IRCD;
require POE::Filter::IRCv3;
my $old = POE::Filter::IRCD->new;
my $new = POE::Filter::IRCv3->new;

my $basic = ':test!me@test.ing PRIVMSG #Test :This is a test'
            .' but not of the emergency broadcast system'
            .' foo bar baz quux snarf';

my $multiparam = ':test!me@test.ing foo bar baz quux frobulate snack';

my ($ev_old_one, $ev_old_two, $ev_old_three);
my ($ev_new_one, $ev_new_two, $ev_new_three);
my $get_tests = +{
  old_get => sub {
    $ev_old_one   = $old->get([ $basic ]);
    $ev_old_two   = $old->get([ 'foo bar' ]);
    $ev_old_three = $old->get([ $multiparam ]);
  },

  new_get => sub {
    $ev_new_one   = $new->get([ $basic ]);
    $ev_new_two   = $new->get([ 'foo bar' ]);
    $ev_new_three = $new->get([ $multiparam ]);
  },
};

cmpthese( 200_000, $get_tests );
timethese( 200_000, $get_tests );

my $put_tests = +{
  old_put => sub {
    my $foo = $old->put([ @$ev_old_one ]);
    my $bar = $old->put([ @$ev_old_two ]);
    my $baz = $old->put([ @$ev_old_three ]);
  },

  new_put => sub {
    $new->put([ @$ev_new_one ]);
    $new->put([ @$ev_new_two ]);
    $new->put([ @$ev_new_three ]);
  },
};

cmpthese( 200_000, $put_tests );
timethese( 200_000, $put_tests );

