#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 5;

# setup library path
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

use ok 'TestApp';
use Test::WWW::Mechanize::Catalyst 'TestApp';

# suppress warnings from next that seem to occure between compile and run-time
BEGIN{ $SIG{__WARN__} = sub{} }; $SIG{__WARN__} = undef;

my $mech = Test::WWW::Mechanize::Catalyst->new;
$mech->get_ok('http://localhost/', 'get main page');
$mech->content_like(qr/it works/i, 'see if it has our text');

ok(
  ! TestApp->isa('TestApp::Plugin::TestPlugin'),
  'Local plugin got ignored'
);

ok(
  ! TestApp->isa('TestApp::MorePlugins::AnotherPlugin'),
  'Another local plugin got ignored'
);
