package BuildTracer::Builder;

use MT::Util qw( is_valid_url decode_url encode_html );
use MT::I18N qw( substr_text length_text );

our @BUILD_LOG;
our $DEPTH;
our $IGNORE_ERROR;
our %VAR_STOCK;
our %LAST_VAR;
our @TRACE_VARS;
our %STASH_STOCK;
our %LAST_STASH;
our @TRACE_STASH;
our ($TIMING, $START_TIME, $TOTAL_TIME);

sub init {
    my $param = shift;
    $param = {} if !defined $param;
    @BUILD_LOG = ();
    $DEPTH = 0;
    $IGNORE_ERROR = 1;
    $START_TIME = undef;
    $TIMING = $param->{no_timing} ? 0 : 1;
}

sub builder { \&psuedo_builder }

sub log { \@BUILD_LOG }

sub total_time { $TOTAL_TIME };

sub build_log {
    my ($ctx, $log) = @_;
    if ('HASH' ne ref $log) {
        $log = { 'type' => $log };
    }
    my $vars = $ctx->{__stash}{vars};
    foreach my $v (keys %$vars){
        $VAR_STOCK{$v} = { 'var_name' => $v };
    }
    diff_vars($ctx);
    $log->{id} = scalar @BUILD_LOG;
    push @BUILD_LOG, $log;
}

sub diff_vars {
    my $ctx = shift;
    my (@diffs);
    my $vars = $ctx->{__stash}{vars};
    foreach my $v (keys(%VAR_STOCK)) {
        if( exists $LAST_VAR{$v} ) {
            my $old = $LAST_VAR{$v};
            if ( exists $vars->{$v} ) {
                my $new = $vars->{$v};
                $new = $new          ? $new
                     : defined($new) ? '0'
                     :                 'undef';
                if ($old ne $new) {
                    push @diffs, {
                        name  => $v,
                        exist => 1,
                        val   => $new,
                    };
                    $LAST_VAR{$v} = $new;
                }
            }
            else {
                push @diffs, {
                    name  => $v,
                    exist => 0,
                };
                delete $LAST_VAR{$v};
            }
        }
        else {
            if ( exists $vars->{$v} ) {
                my $new = $vars->{$v};
                $new = $new          ? $new
                     : defined($new) ? '0'
                     :                 'undef';
                push @diffs, {
                    name  => $v,
                    exist => 1,
                    val   => $new,
                };
                $LAST_VAR{$v} = $new;
            }
        } 
    }

    if ( scalar @diffs ) {
        push @BUILD_LOG, { 
            'type'     => 'diff_vars',
            'diff'     => \@diffs,
        };
    }
}

#base on MT::Builder::build. taken from MTOS4.1 stable. 
sub psuedo_builder {
    my $build = shift;
    my($ctx, $tokens, $cond) = @_;
    
    if ((!defined $START_TIME) && $TIMING) {
        $START_TIME = [ Time::HiRes::gettimeofday() ];
    }
    my $begin_block_log = { 'type' => 'enter_build', 'depth' => $DEPTH };
    build_log( $ctx, $begin_block_log );
    $DEPTH++;
    #print STDERR syntree2str($tokens,0) unless $count++ == 1;

    if ($cond) {
        my %lcond;
        # lowercase condtional keys since we're storing tags in lowercase now
        %lcond = map { lc $_ => $cond->{$_} } keys %$cond;
        $cond = \%lcond;
    } else {
        $cond = {};
    }
    $ctx->stash('builder', $build);
    my $res = '';
    my $ph = $ctx->post_process_handler;

    for my $t (@$tokens) {
        my $is_block = $t->[2] ? 1 : 0;
        my ($pre_handle_log, $post_handle_log);
        $pre_handle_log = { 'depth' => $DEPTH, 'type' => 'pre', 'block' => $is_block};
        $post_handle_log = { 'depth' => $DEPTH, 'type' => 'post', 'block' => $is_block};

        if ($t->[0] eq 'TEXT') {
            my $out = $t->[1];
            $out =~ s!^\s*?\n!!m;
            $out =~ s!^\n\s*?$!!m;
            $out =~ s!^\s*$!!m;
            build_log($ctx, { type => 'text', out => $out }) if $out;
            $res .= $t->[1];
        }
        elsif ($t->[0] eq 'START_TOKENS') {
            build_log($ctx, 'start_tokens');
        }
        elsif ($t->[0] eq 'START_TOKENS_ELSE') {
            build_log($ctx, 'start_tokens_else');
        }
        elsif ($t->[0] eq 'END_TOKENS') {
            build_log($ctx, 'end_tokens');
        }
        else {
            my($tokens, $tokens_else, $uncompiled);
            my $tag = lc $t->[0];
            $pre_handle_log->{tag} = $t->[0];
            $post_handle_log->{tag} = $t->[0];
            $post_handle_log->{include} = 1 if ($tag eq 'include');
            if ($cond && (exists $cond->{ $tag } && !$cond->{ $tag })) {
                # if there's a cond for this tag and it's false,
                # walk the children and look for an MTElse.
                # the children of the MTElse will become $tokens
                for my $tok (@{ $t->[2] }) {
                    if (lc $tok->[0] eq 'else' || lc $tok->[0] eq 'elseif') {
                        $tokens = $tok->[2];
                        unshift @$tokens, ['START_TOKENS_ELSE'];
                        push @$tokens, ['END_TOKENS'];
                        $uncompiled = $tok->[3];
                        $pre_handle_log->{cond} = "FALSE";
                        last;
                    }
                }
                next unless $tokens;
            } else {
                if ($t->[2] && ref($t->[2])) {
                    # either there is no cond for this tag, or it's true,
                    # so we want to partition the children into
                    # those which are inside an else and those which are not.
                    ($tokens, $tokens_else) = ([], []);
                    for my $sub (@{ $t->[2] }) {
                        if (lc $sub->[0] eq 'else' || lc $sub->[0] eq 'elseif') {
                            push @$tokens_else, $sub;
                        } else {
                            push @$tokens, $sub;
                        }
                    }
                    unshift @$tokens, ['START_TOKENS'];
                    push @$tokens, ['END_TOKENS'];
                    unshift @$tokens_else, ['START_TOKENS_ELSE'];
                    push @$tokens_else, ['END_TOKENS'];
                }
                $uncompiled = $t->[3];
            }
            my($h, $type) = $ctx->handler_for($t->[0]);
            if ($h) {
                my $start;
                if ($MT::DebugMode & 8) {
                    require Time::HiRes;
                    $start = [ Time::HiRes::gettimeofday() ];
                }
                my $tag_start_time;
                if ($TIMING) {
                    $tag_start_time = [ Time::HiRes::gettimeofday() ];
                }
                local($ctx->{__stash}{tag}) = $t->[0];
                local($ctx->{__stash}{tokens}) = ref($tokens) ? bless $tokens, 'MT::Template::Tokens' : undef;
                local($ctx->{__stash}{tokens_else}) = ref($tokens_else) ? bless $tokens_else, 'MT::Template::Tokens' : undef;
                local($ctx->{__stash}{uncompiled}) = $uncompiled;
                my %args = %{$t->[1]} if defined $t->[1];
                my @args = @{$t->[4]} if defined $t->[4];

                # process variables
                my $arg_str;
                foreach my $v (keys %args) {
                    if (ref $args{$v} eq 'ARRAY') {
                        $arg_str .= ' ' . $v . '="ARRAY"';
                        foreach (@{$args{$v}}) {
                            if (m/^\$([A-Za-z_](\w|\.)*)$/) {
                                $_ = $ctx->var($1);
                            }
                        }
                    } else {
                        $arg_str .= ' ' . $v . '="' . $args{$v} . '"';
                        if ($args{$v} =~ m/^\$([A-Za-z_](\w|\.)*)$/) {
                            $args{$v} = $ctx->var($1);
                        }
                    }
                }
                $pre_handle_log->{args} = $arg_str;
                foreach (@args) {
                    $_ = [ $_->[0], $_->[1] ];
                    my $arg = $_;
                    if (ref $arg->[1] eq 'ARRAY') {
                        $arg->[1] = [ @{$arg->[1]} ];
                        foreach (@{$arg->[1]}) {
                            if (m/^\$([A-Za-z_](\w|\.)*)$/) {
                                $_ = $ctx->var($1);
                            }
                        }
                    } else {
                        if ($arg->[1] =~ m/^\$([A-Za-z_](\w|\.)*)$/) {
                            $arg->[1] = $ctx->var($1);
                        }
                    }
                }

                build_log($ctx, $pre_handle_log);
                # Stores a reference to the ordered list of arguments,
                # just in case the handler wants them
                local $args{'@'} = \@args;
                my $out = $h->($ctx, \%args, $cond);
                my $err;
                unless (defined $out) {
                    $err = $ctx->errstr;
                    if (defined $err) {
                        if ($IGNORE_ERROR){
                            $pre_handle_log->{error} = 1;
                            $out = '';
                        }
                        else {
                            return $build->error(MT->translate("Error in <mt:[_1]> tag: [_2]", $t->[0], $ctx->errstr));
                        }
                    }
                    else {
                        # no error was given, so undef will mean '' in
                        # such a scenario
                        $out = '';
                    }
                }

                if ((defined $type) && ($type == 2)) {
                    # conditional; process result
                    $out = $out ? $ctx->slurp(\%args, $cond) : $ctx->else(\%args, $cond);
                    delete $ctx->{__stash}{vars}->{__value__};
                    delete $ctx->{__stash}{vars}->{__name__};
                }

                $out = $ph->($ctx, \%args, $out, \@args)
                    if %args && $ph;
                $post_handle_log->{out} = $pre_handle_log->{error} ? $err : $out;
                my $trimed_out = $post_handle_log->{out};
                if (40 < length_text($trimed_out)) {
                    $trimed_out = substr_text($trimed_out, 0, 40) . '...';
                }
                $post_handle_log->{trimed_out} = $trimed_out;
                build_log($ctx, $post_handle_log);
                $post_handle_log->{ 'pair_id' } = $pre_handle_log->{ 'id' };
                $pre_handle_log->{ 'pair_id' } = $post_handle_log->{ 'id' };
                $res .= $out
                    if defined $out;
                if ($MT::DebugMode & 8) {
                    my $elapsed = Time::HiRes::tv_interval($start);
                    print STDERR "Builder: Tag [" . $t->[0] . "] - $elapsed seconds\n" if $elapsed > 0.25;
                }
                if ($TIMING) {
                    $post_handle_log->{ 'elapsed' } = sprintf("%f", Time::HiRes::tv_interval($tag_start_time));
                    $post_handle_log->{ 'elapsed_total' } = sprintf("%f", Time::HiRes::tv_interval($START_TIME));
                }
            } else {
                if ($t->[0] !~ m/^_/) { # placeholder tag. just ignore
                    if ($IGNORE_ERROR){
                        build_log($ctx, {
                            type => 'error',
                            out  => MT->translate("Unknown tag found: [_1]", $t->[0]),
                        });
                    }
                    else {
                        return $build->error(MT->translate("Unknown tag found: [_1]", $t->[0]));
                    }
                }
            }
        }
    }
    $DEPTH--;
    my $end_block_log = { 'type' => 'exit_build' };
    build_log( $ctx, $end_block_log );
    $end_block_log->{ 'pair_id' } = $begin_block_log->{ 'id' };
    $begin_block_log->{ 'pair_id' } = $end_block_log->{ 'id' };
    $TOTAL_TIME = sprintf("%f", Time::HiRes::tv_interval($START_TIME))
        if $TIMING;
    
    return $res;
}

1;
