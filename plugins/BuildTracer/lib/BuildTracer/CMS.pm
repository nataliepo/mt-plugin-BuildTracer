package BuildTracer::CMS;

use strict;
use MT::Util qw( decode_url encode_html );

sub list_fileinfo {
    my $app = shift;
    if ( !$app->user->is_superuser ) {
        return $app->errtrans("Permission denied.");
    }

    require MT::FileInfo;
    require MT::Template;

    my $plugin = MT::Plugin::BuildTracer->instance;
    my %param;
    my $blog_id = $app->param('blog_id');
    my $filter  = $app->param('filter');
    (my $limit  = $app->param('limit')  ) ||= 20;
    (my $offset = $app->param('offset') ) ||= 0;

    #At first, build indexes.
    my $iter = MT::FileInfo->load_iter({
        'blog_id'      => $blog_id,
        'archive_type' => 'index',
    });
    my @indexes;
    while(my $fi = $iter->()) {
        my $tmpl = MT::Template->load({ 'id' => $fi->template_id});
        push @indexes, {
            'tmpl_name' => $tmpl->name,
            'url' => $fi->url,
        };
    }
    
    my @data;
    my $total;
    my $key_tmpl_name;
    if ( $filter =~ /^\d+$/ ) {
        my $tmpl_id = $filter;
        my $terms = { 'template_id' => $tmpl_id, };
        $total = MT::FileInfo->count( $terms );
        my $args  = { 'limit'  => $limit + 1,
                      'offset' => $offset,
                      'sort'   => 'url',
                    };
        if ( $total && $offset > $total - 1 ) {
            $args->{offset} = $offset = $total - $limit;
        }
        elsif ( ( $offset < 0 ) || ( $total - $offset < $limit ) ) {
            $args->{offset} = $offset = 0;
        }
        else {
            $args->{offset} = $offset if $offset;
        }

        @data = MT::FileInfo->load( $terms, $args );

        ## We tried to load $limit + 1 entries above; if we actually got
        ## $limit + 1 back, we know we have another page of fileinfos.
        my $have_next_fi = @data > $limit;
        pop @data while @data > $limit;
        if ($offset) {
            $param{prev_offset}     = 1;
            $param{prev_offset_val} = $offset - $limit;
            $param{prev_offset_val} = 0 if $param{prev_offset_val} < 0;
        }
        if ($have_next_fi) {
            $param{next_offset}     = 1;
            $param{next_offset_val} = $offset + $limit;
        }
        my $key_tmpl = MT::Template->load({ id => $tmpl_id });
        $key_tmpl_name = $key_tmpl->name;
    }
    else {
        $total = scalar @indexes;
        @data = @indexes;
        $key_tmpl_name = 'index templates';
    }

    my @individuals = MT::Template->load({
        blog_id => $blog_id,
        type    => 'individual', 
    });
    my @pages = MT::Template->load({
        blog_id => $blog_id,
        type    => 'page', 
    });
    my @archives = MT::Template->load({
        blog_id => $blog_id,
        type    => 'archive', 
    });

    my $page_tmpl = $plugin->load_tmpl('list_fileinfo.tmpl');
    $param{limit}               = $limit;
    $param{offset}              = $offset;
    $param{list_start}  = $offset + 1;
    $param{list_end}    = $offset + scalar @data;
    $param{list_total}  = $total;
    $param{next_max}    = $param{list_total} - $limit;
    $param{next_max}    = 0 if ( $param{next_max} || 0 ) < $offset + 1;
    $param{show_actions} = 1;
    $param{bar}    = 'Both';
    $param{object_label}            = 'FileInfo';
    $param{object_label_plural}     = 'FileInfos';
    $param{object_type}             = 'fileinfo';
    $param{screen_class} = "list-fileinfo";
    $param{screen_id} = "list-fileinfo";
    $param{listing_screen} = 1;
    $param{position_actions_top} = 1;
    $param{position_actions_bottom} = 1;
    $param{filter_label} = $key_tmpl_name;
    $param{list} = \@data;
    $param{archives} = \@archives;
    $param{individuals} = \@individuals;
    $param{pages} = \@pages;
    $param{indexes}  = \@indexes;
    $param{blog_id} = $blog_id;
    $param{object_loop} = \@data;
    $page_tmpl->param( \%param );
    return $app->build_page($page_tmpl);
}

sub trace {
    my $app = shift;
    my $plugin = MT::Plugin::BuildTracer->instance;
    if ( !$app->user->is_superuser ) {
        return $app->errtrans("Permission denied.");
    }

    require MT::FileInfo;
    require MT::Builder;
    require MT::FileMgr::Local;
    require MT::WeblogPublisher;
    require MT::Template;
    require BuildTracer::Builder;

    my $tmpl = $plugin->load_tmpl('build_tracer.tmpl');
    my $fi_id = $app->param('id');
    my $blog_id = $app->param('blog_id');
    my $url = decode_url( $app->param('url') );
    if ( $url =~ /[ \'\"]/ ) {
        die "invalid url";
    }
    $url =~ s!^https?://[^/]*!!;
    if ( $url =~ /\/$/ ) {
        #TBD: get from blog info... can we do that?
        $url .= 'index.html';
    }

    eval {require Time::HiRes; };
    my $can_timing = $@ ? 0 : 1;
    my $no_timing = $app->param('no_timing');
    my $timing = !$can_timing ? 0
               : $no_timing   ? 0
               :                1;
    my $fi = MT::FileInfo->load({'url' => $url});
    die "unknown url $url"
        unless $fi;
    $blog_id = $fi->blog_id;

    my $error;
    {
        BuildTracer::Builder->init( {'no_timing' => !$timing, });
        local *MT::Builder::build = BuildTracer::Builder->builder;
        local *MT::FileMgr::Local::content_is_updated = sub { 0 };
        my $pub = MT::WeblogPublisher->new;
        $pub->rebuild_from_fileinfo($fi)
            or $error = $pub->errstr;
    }
    my $ft = MT::Template->load({ 'id' => $fi->template_id });
    my $log = BuildTracer::Builder->log;
    $tmpl->param('build_log' => $log);
    my $encoder;
    $encoder = sub {
        my $node = shift;
        if (ref $$node eq 'ARRAY') {
            foreach (@$$node) {
                $encoder->(\$_);
            }
        }
        elsif (ref $$node eq 'HASH') {
            foreach (values %$$node) {
                $encoder->(\$_);
            }
        }
        else {
            $$node = MT::Util::encode_html($$node, 1);
        }
    };

    $encoder->(\$log);
    require JSON;
    my $log_json = JSON::objToJson($log);
    $tmpl->param('log_json' => $log_json );
#    foreach my $v (@TRACE_VARS) {
#        $VAR_STOCK{$v}->{stocked} = 1;
#    }
#    foreach my $s (@TRACE_STASH) {
#        $STASH_STOCK{$s}->{stocked} = 1;
#    }
#    $tmpl->param('varstock' => [ sort { $a->{var_name} cmp $b->{var_name} } values %VAR_STOCK ]);
#    $tmpl->param('stashstock' => [ sort { $a->{stash_name} cmp $b->{stash_name} } values %STASH_STOCK ]);
    $tmpl->param('template_text' => $ft->text );
    $tmpl->param('tmpl_name' => $ft->name );
    $tmpl->param('tmpl_id' => $ft->id );
    $tmpl->param('tmpl_type' => $ft->type );
    $tmpl->param('fi_at' => $fi->archive_type );
    $tmpl->param('fi_url' => $fi->url );
    $tmpl->param('can_timing' => $can_timing);
    $tmpl->param('timing' => $timing );
    $tmpl->param('total_time' => BuildTracer::Builder->total_time);
    $tmpl->param('id' => $fi_id );
    $tmpl->param('blog_id' => $blog_id);
    $tmpl->param('error' => $error);
    $tmpl->param('buildtracer_debug' => $app->config('BuildTracerDebugMode'));
    return $app->build_page($tmpl);
}

1;
