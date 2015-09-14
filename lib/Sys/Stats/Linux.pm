package Sys::Stats::Linux;
use 5.010001;
use strict;
use warnings;

use Capture::Tiny   'capture';
use File::Slurper   'read_text';
use File::Spec;
use List::MoreUtils 'firstval';

use parent 'Sys::Stats';

our $VERSION = "0.01";

sub _df_cmd { # {{{
    my $cmd  = '/bin/df';
    my @args = @_;
    my @exclude_fs
        = map { "-x ${_}" }
            qw(none unknown rootfs iso9660 squashfs udf romfs ramfs debugfs cgroup_root devtmpfs); 
    push @args, @exclude_fs;
    my ($out, $err, $exit) = capture { system($cmd, @args) };
    Carp::croak "Cannot call '$cmd @args' : $err"
        if $exit;

    my @lines = split $/, $out;
    shift @lines;

    my @res;
    foreach my $line (@lines) {
        my ($fs, $total, $used, $avail, undef, $mnt) = split(/\s+/, $line, 6);
        $fs =~ s/[^a-zA-Z0-9_]/_/g;
        push @res, +{
                filesystem  => $fs,
                total       => $total,
                used        => $used,
                available   => $avail,
                mount_point => $mnt,
            };
    }
    return @res;
} # }}}

sub disk_usage { return _df_cmd(qw(-P -l)); }

sub inode_usage { return _df_cmd('-i'); }

sub loadavg { # {{{
    my $file = '/proc/loadavg';
    Carp::croak "File '$file' is not readable"
        unless (-r $file);
    my ($avg1, $avg5, $avg15) = split /\s+/, read_text($file);
    return ($avg1, $avg5, $avg15);
} # }}}

sub list_nics { # {{{
    my $file = '/proc/net/dev';
    Carp::croak "File '$file' is not readable"
        unless (-r $file);

    return grep { $_ ne '' }
        map { /^\s*(?<interface>[^:]+):/ ? $+{interface} : '' }
            grep { ! /^\s*(lo|sit\d+):/ }
                split($/, read_text($file));
} # }}}

sub if_stat { # {{{
    my @res;
    foreach my $nic (list_nics()) {
        my $path = "/sys/class/net/$nic/statistics";

        my %stats
            = map {
                    chomp(my $value = read_text(File::Spec->catfile($path, $_)));
                    ($_ => $value)
                }
                qw(rx_bytes rx_packets tx_bytes tx_packets);
        push @res, +{ interface => $nic, %stats };
    }
    return @res;
} # }}}

sub netstat { # {{{
    my $cmd  = '/bin/netstat';
    my @args = qw(-s);
    my ($out, $err, $exit) = capture { system($cmd, @args) };
    # FIXME 20150910 geraud
    # Thank you! https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=541172
    if ($exit) {
        my $ret_code = $exit >> 8;
        Carp::croak "Cannot call '$cmd @args' : $err"
            if ($ret_code > 1);
    }

    my @lines = split $/, $out;
    my %res_value_for = (
            'active connections ope'  => "active",
            'passive connection ope'  => "passive",
            'failed connection'       => "failed",
            'connection resets'       => "resets",
            'connections established' => "established",
        );
    my %res;
    foreach my $rx (keys %res_value_for) {
        my $line = firstval { /$rx/ } @lines;
        if ($line) {
            $line =~ s/^\s*//;
            my ($value) = split(/\s+/, $line);
            $res{$res_value_for{$rx}} = $value;
        }
    }
    return %res;
} # }}}

sub memory { # {{{
    my $file = '/proc/meminfo';
    Carp::croak "File '$file' is not readable"
        unless (-r $file);
    
    my %meminfo
        = map {
            my ($key, $val) = split /\s*:\s*/, $_;
            my ($v, $unit)  = split /\s+/, $val;
            $unit //= '';
            $v *= ($unit eq 'mB') ? 1024*1024
                : ($unit eq 'kB') ? 1024
                :                   1;
            ($key => $v);
        }
            split $/, read_text($file);

    my $shmem      = $meminfo{Shmem}     // 0;
    my $cached     = $meminfo{Cached}    // 0;
    my $swap_free  = $meminfo{SwapFree}  // 0;
    my $swap_total = $meminfo{SwapTotal} // 0;
    return (
            total    => $meminfo{MemTotal} // 0,
            active   => $meminfo{Active}   // 0,
            inactive => $meminfo{Inactive} // 0,
            cached   => $cached - $shmem,
            free     => $meminfo{MemFree}  // 0,
            swap     => $swap_total - $swap_free,
            buffers  => $meminfo{Buffers}  // 0,
        );
} # }}}

1;
__END__

=encoding utf-8

=head1 NAME

Sys::Stats::Linux - Linux driver for Sys::Stats.

=head1 VERSION

This document describes Sys::Stats::Linux version 0.01

=head1 DESCRIPTION

You shouldn't use this module directly. Please refer to L<Sys::Stats> instead.

=head1 LICENSE

Copyright (C) Geraud CONTINSOUZAS.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Geraud CONTINSOUZAS E<lt>gcs@cpan.orgE<gt>

=cut

# vim: syn=perl nu ai cin ts=4 et sw=4 fdm=marker
