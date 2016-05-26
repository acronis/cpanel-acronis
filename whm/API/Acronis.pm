#!/usr/local/cpanel/3rdparty/bin/perl

package Cpanel::API::Acronis;

use strict;
use warnings;

use lib '/var/cpanel/perl5/lib';

use Acronis;

sub list_recovery_points {
    my ($args, $result) = @_;

    # Call Acronis::??? to get list of possible recovery points
    # munge them as necessary
    #
    # Put the here
    $result->data();

    return 1;
}

sub recover_file {
    my ($args, $result) = @_;

    # This already checks that "restore_point" and "file" were passed in and are not empty.
    my ($restore_point, $file) = $args->get_required_length(qw/ restore_point file /);

    # Call Acronis::??? to start a recovery.
    # Do we wait for the process to finish?

    # If it fails, throw an exception (die "recovery couldn't be completed because you didn't wash your hands";)

    $result->data();

    return 1;
}