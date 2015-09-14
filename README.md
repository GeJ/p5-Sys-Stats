# NAME

Sys::Stats - Multi-platform, pure perl, system statistics gathering.

# VERSION

This document describes Sys::Stats version 0.01

# SYNOPSIS

    use Sys::Stats;
    
    my $ss = Sys::Stats->new();
    my %stats = $ss->all;

# DESCRIPTION

Sys::Stats is my attempt at having an all-in-one statistics gatherer.
There are many like this one, but this one is mine... well not really.

In order to make this simple I've stolen... hummm, borrowed rather, the
way the Munin project gather data on a host and made it a pure perl
implementation of it (barring slurping `/proc` files and
`system`-ing `/sbin` utilities).

So far, this module will only work on Linux and FreeBSD systems.
Hopefully more drivers will come in the future, oh and Patches welcomed.

# TODO

Those would be nice to have.

- Add more documentation

    List all the methods available and document their returned values.

- Add more drivers

    (Open|Net)BSD and Mac OSX would be nice.

- Add some tests.

    How do you tests ever changing values?

# LICENSE

Copyright (C) Geraud CONTINSOUZAS.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Geraud CONTINSOUZAS &lt;gcs@cpan.org>
