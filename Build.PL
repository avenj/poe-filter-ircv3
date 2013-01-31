#!/usr/bin/env perl
use Module::Build;
use strict; use warnings;

Module::Build->subclass(
  class => 'POE::Filter::IRCv3::_Builder',
)->new(
  module_name   => 'POE::Filter::IRCv3',
  dist_abstract => 'POE::Filter::IRCD with experimental IRCv3 features',
  dist_author   => 'Jon Portnoy <avenj@cobaltirc.org>',
  license       => 'perl',
  create_readme => 1,
  create_makefile_pl => 'small',
  configure_requires => {
    'Module::Build' => '0.38',
  },
  build_requires => {
    'Test::More'    => 0,
  },
  requires => {
    'parent'        => 0,
    'Carp'          => 0,
    'strictures'    => 1,
    'POE::Filter'   => 0,
  },
  meta_merge => {
    resources => {
      repository => 'http://github.com/avenj/poe-filter-ircv3.git',
    },
  },
)->create_build_script;
