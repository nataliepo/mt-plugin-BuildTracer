package MT::Plugin::BuildTracer;

use strict;
use MT;
use MT::Plugin;
@MT::Plugin::BuildTracer::ISA = qw(MT::Plugin);

use vars qw($PLUGIN_NAME $VERSION);
$PLUGIN_NAME = 'BuildTracer';
$VERSION = '0.5';
my $plugin = new MT::Plugin::BuildTracer({
    name => $PLUGIN_NAME,
    version => $VERSION,
    description => "<MT_TRANS phrase='description of BuildTracer'>",
    author_name => 'Akira Sawada',
    author_link => 'http://blog.aklaswad.com/',
    l10n_class => 'BuildTracer::L10N',
});

MT->add_plugin($plugin);

sub instance { $plugin; }

sub doLog {
    my ($msg) = @_; 
    return unless defined($msg);

    use MT::Log;
    my $log = MT::Log->new;
    $log->message($msg) ;
    $log->save or die $log->errstr;
}

sub init_registry {
    my $plugin = shift;

    my $menus = {
        'manage:fileinfo' => {
            label => 'FileInfo',
            mode  => 'list_fileinfo',
            order => 9000,
        },
    };

    my $methods = {
        'list_fileinfo' => 'BuildTracer::CMS::list_fileinfo',
        'build_tracer'  => 'BuildTracer::CMS::trace',
    };

    $plugin->registry({
        config_settings => {
            'BuildTracerDebugMode' => { default => 0, },
        },
        applications => {
            cms => {
                menus   => $menus,
                methods => $methods,
            },
        },
    });
}

1;
