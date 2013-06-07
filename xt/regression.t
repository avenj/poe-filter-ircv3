use Test::More;
use strict; use warnings FATAL => 'all';


use POE::Filter::IRCD;
use POE::Filter::IRCv3;

{
  my $old = POE::Filter::IRCD->new;
  my $new = POE::Filter::IRCv3->new;

  my $basic = ':test PRIVMSG foo :bar baz quux';
  my $ev_old = $old->get([ $basic ]);
  my $ev_new = $new->get([ $basic ]);
  is_deeply(
    $ev_new,
    $ev_old,
    'new vs old on basic str get() ok'
  );

  is_deeply( 
    $new->put([$ev_new->[0]]),
    $old->put([$ev_old->[0]]),
    'new vs old on basic str put() ok'
  );
}

{
  my $old = POE::Filter::IRCD->new(colonify => 1);
  my $new = POE::Filter::IRCv3->new(colonify => 1);

  my $str = ':test FOO :bar';
  my $ev_old = $old->get([ $str ]);
  my $ev_new = $new->get([ $str ]);
  is_deeply(
    $ev_new,
    $ev_old,
    'new vs old get() with colonify => 1 ok'
  );

  my $par_old = $old->put([ @$ev_old ]);
  my $par_new = $new->put([ @$ev_new ]);
  is_deeply(
    $par_new,
    $par_old,
    'new vs old put() with colonify => 1 ok'
  );
}

{
  my $old = POE::Filter::IRCD->new(colonify => 0);
  my $new = POE::Filter::IRCv3->new(colonify => 0);
  
  my $str = ':test FOO bar';
  my $ev_old = $old->get([ $str ]);
  my $ev_new = $new->get([ $str ]);
  is_deeply(
    $ev_new,
    $ev_old,
    'new vs old get() with colonify => 0 ok'
  );

  my $par_old = $old->put([ @$ev_old ]);
  my $par_new = $new->put([ @$ev_new ]);
  is_deeply(
    $par_new,
    $par_old,
    'new vs old put() with colonify => 0 ok'
  );
}

done_testing;
