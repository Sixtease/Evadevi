package Evadevi::Util;

use strict;
use utf8;
use Carp;
use Exporter qw(import);
our @EXPORT_OK = qw(run_parallel stringify_options get_filehandle cp);

sub run_parallel {
    my ($commands) = @_;
    my %pid2command;
    for my $command (@$commands) {
        my $forked = fork();
        
        die "fork failed: $!" if not defined $forked;
        
        if ($forked == 0) {
            if (ref $command eq 'CODE') {
                $command->();
            }
            else {
                exec($command);
            }
            exit(0);
        }
        else {
            $pid2command{$forked} = $command;
        }
    }
    for (@$commands) {
        my $pid = wait();
        my $status = $?;
        next if $pid < 0;
        if ($status > 0) {
            die "command '$pid2command{$pid}' failed with status $status"
        }
    }
}

sub stringify_options {
    my @parts;
    for my $i (0 .. $#_) {
        next if $i % 2;
        
        my $o = $_[$i];
        my $vs = $_[$i+1];
        
        warn "option not starting with dash: '$o' in '@_'" if substr($o,0,1) ne '-' and length $o > 0 and $o !~ /^\d?>$/;
        
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

sub get_filehandle {
    my ($f, $mode) = (@_, '<');
    if (ref($f) =~ /\b(?:IO|GLOB)\b/) {
        return $f
    }
    else {
        open my $fh, $mode, $f or croak "Couldn't open '$f' in mode '$mode': $!";
        return $fh
    }
}

sub cp {
    my ($in_file, $out_file) = @_;
    my $in_fh  = get_filehandle($in_file);
    my $out_fh = get_filehandle($out_file, '>');
    print {$out_fh} <$in_fh>;
}

1

__END__
