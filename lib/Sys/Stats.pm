package Sys::Stats;
use 5.010001;
use strict;
use warnings;

use Carp ();

our $VERSION = "0.01";

sub new {
    my $driver = 'Sys::Stats::' . ucfirst($^O);
    eval "require $driver";
    if ($@) {
        Carp::croak "Can't find a proper class for OS $^O : $@";
    }
    return bless {}, $driver;
}

sub all {
    my $self = shift;
    return (
            disk_usage   => [$self->disk_usage],
            inode_usage  => [$self->inode_usage],
            load_average => [$self->loadavg],
            if_stat      => [$self->if_stat],
            netstat      => {$self->netstat},
            memory       => {$self->memory},
        );
}

1;
__END__

=encoding utf-8

=head1 NAME

Sys::Stats - Multi-platform, pure perl, system statistics gathering.

=head1 VERSION

This document describes Sys::Stats version 0.01

=head1 SYNOPSIS

    use Sys::Stats;
    
    my $ss = Sys::Stats->new();
    my %stats = $ss->all;

=head1 DESCRIPTION

Sys::Stats is my attempt at having an all-in-one statistics gatherer.
There are many like this one, but this one is mine... well not really.

In order to make this simple I've stolen... hummm, borrowed rather, the
way the Munin project gather data on a host and made it a pure perl
implementation of it (barring slurping C<< /proc >> files and
C<< system >>-ing C<< /sbin >> utilities).

So far, this module will only work on Linux and FreeBSD systems.
Hopefully more drivers will come in the future, oh and Patches welcomed.

=head1 TODO

Those would be nice to have.

=over 4

=item Add more documentation

List all the methods available and document their returned values.

=item Add more drivers

(Open|Net)BSD and Mac OSX would be nice.

=item Add some tests.

How do you tests ever changing values?

=back

=head1 LICENSE

Copyright (C) Geraud CONTINSOUZAS.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Geraud CONTINSOUZAS E<lt>gcs@cpan.orgE<gt>

=cut

# vim: syn=perl nu ai cin ts=4 et sw=4 fdm=marker
