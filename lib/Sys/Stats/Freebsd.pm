package Sys::Stats::Freebsd;
use 5.010001;
use strict;
use warnings;

use Capture::Tiny   'capture';
use List::MoreUtils 'firstval';

use parent 'Sys::Stats';

our $VERSION = "0.01";

sub disk_usage { # {{{
    my $cmd  = '/bin/df';
    my @args = (
            '-P',
            '-k', 
            '-t', 
            join(',',qw(noprocfs devfs fdescfs linprocfs linsysfs nfs nullfs cd9660))
        );

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

sub inode_usage { # {{{
    my $cmd  = '/bin/df';
    my @args = (
            '-i',
            '-t', 
            join(',',qw(noprocfs devfs fdescfs linprocfs linsysfs nfs nullfs cd9660))
        );
    my ($out, $err, $exit) = capture { system($cmd, @args) };
    Carp::croak "Cannot call '$cmd @args' : $err"
        if $exit;

    my @lines = split $/, $out;
    shift @lines;

    my @res;
    foreach my $line (@lines) {
        my ($fs, undef, undef, undef, undef, $used, $avail, undef, $mnt) = split(/\s+/, $line, 9);
        $fs =~ s/[^a-zA-Z0-9_]/_/g;
        push @res, +{
                filesystem  => $fs,
                total       => $used + $avail,
                used        => $used,
                available   => $avail,
                mount_point => $mnt,
            };
    }
    return @res;
} # }}}

sub loadavg { # {{{
    my $cmd  = '/sbin/sysctl';
    my @args = qw(-n vm.loadavg);
    my ($out, $err, $exit) = capture { system($cmd, @args) };
    Carp::croak "Cannot call '$cmd @args' : $err"
        if $exit;

    my (undef, $avg1, $avg5, $avg15) = split /\s+/, $out;
    return ($avg1, $avg5, $avg15);
} # }}}

sub list_nics { # {{{
    my $cmd = '/usr/bin/netstat';
    my @args = qw(-i -b -n);
    my ($out, $err, $exit) = capture { system($cmd, @args) };
    Carp::croak "Cannot call '$cmd @args' : $err"
        if $exit;

    my @lines = split $/, $out;
    shift @lines;
    my @res;
    foreach my $line (@lines) {
        next if ( $line =~ m{^(faith|lo\d|pflog)} );
        if ( $line =~ m{<Link#[0-9]*>} ) {
            $line =~ s/\** .*//;
            push @res, $line;
        }
    }
    return @res;
} # }}}

sub if_stat { # {{{
    my $cmd = '/usr/bin/netstat';
    my @args = qw(-i -b -n);
    my ($out, $err, $exit) = capture { system($cmd, @args) };
    Carp::croak "Cannot call '$cmd @args' : $err"
        if $exit;

    my @lines = split $/, $out;
    shift @lines;
    my @res;
    foreach my $line (@lines) {
        # Ignore pseudo interfaces
        next if ( $line =~ m{^(faith|lo\d|pflog)} );

        if ( $line =~ m{<Link#[0-9]*>} ) {
            my @e = split /\s+/, $line;
            # Down interface has a '*' marker appended to it. Remove it.
            $e[0] =~ s/\**$//;

            # KLUDGE 20150910 geraud
            # The munin code says (in awk style)
            # if (NF == 10) { 
            #     rbytes = $6; obytes = $9;
            # } else {
            #     rbytes = $7; obytes = $10;
            # }
            # Problem is, on my box, NF is either 11 or 12, and I can't find a
            # netstat(1) with a 10 columns output (oldest available is 8.4). 
            # For now, adjust accordingly.
            my $base_idx
                = (@e == 11) ?  3 
                : (@e == 12) ?  4
                :               0;
            next unless $base_idx;

            push @res, +{
                interface =>  $e[0],
                rx_packets => $e[$base_idx],
                rx_bytes  =>  $e[$base_idx + 3],
                tx_packets => $e[$base_idx + 4],
                tx_bytes  =>  $e[$base_idx + 6],
            };
        }
    }
    return @res;
} # }}}

sub netstat { # {{{
    my $cmd  = '/usr/bin/netstat';
    my @args = qw(-s);
    my ($out, $err, $exit) = capture { system($cmd, @args) };
    Carp::croak "Cannot call '$cmd @args' : $err"
        if $exit;

    my @lines = split $/, $out;
    my %res_value_for = (
            'connection requests'     => "active",
            'connection accepts'      => "passive",
            'bad connection'          => "failed",
            'reset$'                  => "resets",
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

sub _swapinfo { # {{{
    my $cmd  = '/usr/sbin/swapinfo';
    my @args = qw(-k);
    my ($out, $err, $exit) = capture { system($cmd, @args) };
    Carp::croak "Cannot call '$cmd @args' : $err"
        if $exit;

    my @lines = split $/, $out;
    shift @lines;
    my @res;
    foreach my $line (@lines) {
        my ($device, $total, $used, $avail, undef) = split /\s+/, $line;
        push @res, +{
                device => $device,
                total  => $total,
                used   => $used,
            };
    }
    return @res;
} # }}}

sub memory { # {{{
    my $cmd  = '/sbin/sysctl';

    my %sysctl_for = (
            'vm.stats.vm.v_page_size'      => 'pagesize',
            'vm.stats.vm.v_page_count'     => 'memsize',
            'vm.stats.vm.v_active_count'   => 'active_count',
            'vm.stats.vm.v_inactive_count' => 'inactive_count',
            'vfs.bufspace'                 => 'buffers_count',
            'vm.stats.vm.v_cache_count'    => 'cache_count',
            'vm.stats.vm.v_free_count'     => 'free_count',
        );
    my @args = (keys(%sysctl_for));
    my ($out, $err, $exit) = capture { system($cmd, @args) };
    Carp::croak "Cannot call '$cmd @args' : $err"
        if $exit;

    my @lines = split $/, $out;
    my %count_of = map {
            my ($sysctl, $val) = split(/:/, $_);
            $val =~ s/\D//g;
            ($sysctl_for{$sysctl} => $val)
        }
        @lines;

    # FIXME 20150914 geraud
    # Can't seem to find a viable way to get the swap usage via sysctl.
    my $swap_used = 0;
    foreach my $swap (_swapinfo()) {
        $swap_used += $swap->{used};
    }

    my $page_size = $count_of{pagesize};
    return (
            total    => $count_of{memsize}        * $page_size,
            active   => $count_of{active_count}   * $page_size,
            inactive => $count_of{inactive_count} * $page_size,
            cached   => $count_of{cache_count}    * $page_size,
            free     => $count_of{free_count}     * $page_size,
            swap     => $swap_used                * 1024,
            buffers  => $count_of{buffers_count},
        );
} # }}}

1;
__END__

=encoding utf-8

=head1 NAME

Sys::Stats::Freebsd - FreeBSD driver for Sys::Stats.

=head1 VERSION

This document describes Sys::Stats::Freebsd version 0.01

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
