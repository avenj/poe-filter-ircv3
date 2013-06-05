use strictures 1;
use Benchmark ':all';

my $basic_raw = ':test!me@test.ing PRIVMSG #Test :This is a test';
my $with_tags = '@intent=ACTION;znc.in/extension=value;foobar'.
                ' :test!me@test.ing PRIVMSG #Test :This is a test';

require POE::Filter::IRCv3;
require POE::Filter::IRCv3::NoRE;

timethese( 200_000, {

    regex => sub {
      my $filter = POE::Filter::IRCv3->new;

      $filter->get([ $basic_raw ]);
      $filter->get([ $with_tags ]);
    },

    string => sub {
      my $filter = POE::Filter::IRCv3::NoRE->new;

      $filter->get([ $basic_raw ]);
      $filter->get([ $with_tags ]);
    },

});
