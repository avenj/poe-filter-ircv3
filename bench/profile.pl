use strictures 1;
use Benchmark ':all';

require POE::Filter::IRCD;
require POE::Filter::IRCv3;
my $old = POE::Filter::IRCD->new;
my $new = POE::Filter::IRCv3->new;

my $basic = ':test!me@test.ing PRIVMSG #Test :This is a test';

my $tests = +{
  new => sub {
    $new->get([$basic]);
    $new->get([':foo bar']);
  },
};

$tests->{new}->() for 1 .. 40_000;
