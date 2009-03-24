package TestApp;
use strict;
use warnings;

use CatalystX::PluginLoader qw/with_local_plugins/;
use Catalyst with_local_plugins();

__PACKAGE__->setup;

1;
