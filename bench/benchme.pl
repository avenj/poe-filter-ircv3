use strictures 1;
use Benchmark ':all';

my $basic_raw = ':test!me@test.ing PRIVMSG #Test :This is a test';
my $with_tags = '@intent=ACTION;znc.in/extension=value;foobar'.
                ' :test!me@test.ing PRIVMSG #Test :This is a test';

require POE::Filter::IRCv3;
require POE::Filter::IRCv3::NoRE;

my $refilter = POE::Filter::IRCv3->new;
my $filter = POE::Filter::IRCv3::NoRE->new;
timethese( 200_000, {

    regex => sub {
      $refilter->get([ $basic_raw ]);
      $refilter->get([ $with_tags ]);
    },

    string => sub {
      $filter->get([ $basic_raw ]);
      $filter->get([ $with_tags ]);
    },

});
