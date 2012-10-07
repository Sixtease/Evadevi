package Evadevi::Util;

use strict;
use utf8;
use Exporter qw(import);
our @EXPORT_OK = qw(run_parallel stringify_options);

sub run_parallel {
    my ($commands) = @_;
    for my $command (@$commands) {
        my $forked = fork();
        
        die "fork failed: $!" if not defined $forked;
        
        if ($forked == 0) {
            if (ref $command eq 'CODE') {
                $command->();
            }
            else {
                my $error = system($command);
                if ($error) {
                    die "command '$command' failed with status $error"
                }
            }
            exit(0);
        }
    }
    wait() for @$commands;
}

sub stringify_options {
    my %opt = @_;
    my @parts;
    for my $i (0 .. $#_) {
        next if $i % 2;
        
        my $o = $_[$i];
        my $vs = $opt{$o};
        
        warn "option not starting with dash: '$o' in '@_'" if substr($o,0,1) ne '-' and length $o > 0;
        
        if (ref $vs ne 'ARRAY') {
            $vs = [$vs];
        }
        
        for my $v (@$vs) {
            my $do_quote = 1;
            my $val;
            
            if (ref $v eq 'HASH') {
                if ($v->{no_quotes}) {
                    $do_quote = 0;
                }
                $val = $v->{val};
            }
            elsif (length $v > 0) {
                $val = $v;
            }
            
            if ($do_quote) {
                $val = qq("$val");
            }
            
            if (length $v == 0) {
                push @parts, $o;
            }
            elsif (length $o == 0) {
                push @parts, $val;
            }
            else {
                push @parts, $o, $val;
            }
        }
    }
    return(join ' ', @parts)
}

1

__END__
