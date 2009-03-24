package CatalystX::PluginLoader;

use strict;
use warnings;

BEGIN { require 5.008001; }

use version;
our $VERSION = '0.01';

=pod

=head1 NAME

CatalystX::PluginLoader - Load plugins depending on local config

=head1 SYNOPSIS

 In MyApp.pm:

  use CatalystX::PluginLoader with_local_plugins => {

    # search local config in this path resp. use this file
    # ( __HOST__ is expanded with Sys::Hostname )
    config      => 'etc/__HOST__',

    # search path for '-LocalPlugin' syntax, default is 'MyApp::Plugin'
    plugin_path => [ 'MyApp::MorePlugins' ]
  };

  use Catalyst with_local_plugins(

    # ... normal catalyst plugins ...

    # search for plugin in MyApp::MorePlugins
    '-LocalPlugin',
  );

  # loading local plugins can be done in your local config
  # file ( default confis will be ignored by design)

Loading local plugins with myapp_local.conf:

 <PluginLoader>
   libs /src/experimental/ext_lib
   <plugins>
     prepend StackTrace
     append  FirePHP
     append  -YourLocalPlugin
   </plugins>
 </PluginLoader>

=head1 DESCRIPTION

B<CatalystX::PluginLoader> can be used to load some plugins depending
local configuration files and eases the use of plugins in namespaces other
than C<Catalyst::Plugin>. It tries its best to emulate the semantics
of L<Catalyst::Plugin::ConfigLoader> and
L<Catalyst::Plugin::ConfigLoader::Multi> to find and parse config files
but you are free to use any file and any format that is compatible
with L<Config::Any>.

=cut

use Sys::Hostname;
use Config::Any 0.13;
use Catalyst::Utils;
use Path::Class qw/file dir/;
use List::MoreUtils qw/first_value/;
use Class::Inspector;

use Sub::Exporter -setup => {
  exports => [
    with_local_plugins => \&_build_plugin_filter
  ]
};

sub _build_plugin_filter {
  my ($class, $name, $arg, $cols) = @_;

  my $app = do{
    my $lvl = 1;
    while ( caller( $lvl ) =~ /Sub::Exporter/ ) { $lvl += 1; }
    caller( $lvl );
  };

  my $config = _fetch_config( $app, $arg );

  for ( @{ $config->{libs} || [] } ) {
    s/__HOME__/ Catalyst::Utils::home( $app ) /e;
    eval "use lib '$_';";
    die $@ if $@;
  }

  my @prepended_plugins  = @{ $config->{plugins}{prepend}  || [] };
  my @appended_plugins   = @{ $config->{plugins}{append}   || [] };

  my @module_search_path = @{ $arg->{plugin_path} || [ "${app}::Plugin" ] };
  unshift @module_search_path, @{ $config->{namespace} || [] };

  my $find_module = sub{
    return $_ unless m/^-([\w:]+$)/;
    my $module = $1;
    my $real_path = first_value{
      Class::Inspector->installed( "${_}::${module}" );
    } @module_search_path;
    die "Can't find $module in namespaces ".
      join( ', ', @module_search_path ) . "\nINC was: @INC"
        unless $real_path;
    return "+${real_path}::${module}";
  };

  return sub{
    my @module_list = @_ > 1 ? @_ :
      @_ ? ( grep{ $_ } split /(?:\s|\n)+/s, $_[0] ) : ();
    return map{ $find_module->() } (
      @prepended_plugins, @module_list, @appended_plugins,
    );
  };
}

sub _fetch_config {
  my ( $app, $arg ) = @_;

  my $home = Catalyst::Utils::home( $app )
    or die "Can't find home for ${app}";

  my %app_env = (
    home         => dir( $home ),
    path_prefix  => Catalyst::Utils::appprefix( $app ),
    env_prefix   => Catalyst::Utils::class2env( $app ),
    local_suffix => $ENV{ MYAPP_CONFIG_LOCAL_SUFFIX }
      || $ENV{ CATALYST_CONFIG_LOCAL_SUFFIX } || 'local',
  );

  my $all_existsing_conf_files = sub {
    grep{ -f $_->stringify } map{ $_[0]->file(
      sprintf('%s_%s.%s', @app_env{qw/path_prefix local_suffix/}, $_ )
    )} Config::Any->extensions;
  };

  my @conf_files = $all_existsing_conf_files->( $app_env{home} );

  # support for Catalyst::Plugin::ConfigLoader::Multi envs
  if ( my $local_file = $ENV{ $app_env{env_prefix} . '_CONFIG_MULTI' } ) {
    unshift @conf_files, file( $local_file );
  }

  if ( $arg->{config} ) {
    ( my $conf_path = $arg->{config} ) =~ s/ __HOST__ / hostname() /ex;
    $conf_path = dir( $conf_path );
    $conf_path = $app_env{home}->subdir( $conf_path )
      unless $conf_path->absolute;
    if ( -d $conf_path->stringify ) {
      unshift @conf_files, $all_existsing_conf_files->( $conf_path );
    } else {
      unshift @conf_files, file( $conf_path->stringify );
    }
  }

  my $cfg = Config::Any->load_files({
    files           => \@conf_files,
    use_ext         => 1,
    flatten_to_hash => 1,
  });

  my $most_relevant_config = first_value {
    exists $cfg->{$_} and exists $cfg->{$_}{PluginLoader}
  } @conf_files;

  return $most_relevant_config ?
    $cfg->{ $most_relevant_config }{PluginLoader} : {};

}

1;

__END__

=head1 BUGS

Plenty, I guess. Especially the code for finding local config files
is untested in many scenarios. Bug reports, patches and pull requests welcome.
Remember, this is a early version of and hasn't seen wide-spread testing.

=head1 SOURCE AVAILABILITY

This code is in Github:

 git://github.com/willert/catalystx-pluginloader.git

=head1 SEE ALSO

L<http://github.com/willert/catalystx-pluginloader/>,
L<Catalyst::Runtime>, L<Catalyst::ConfigLoader>

=head1 AUTHOR

Sebastian Willert, C<willert@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Sebastian Willert E<lt>willert@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
