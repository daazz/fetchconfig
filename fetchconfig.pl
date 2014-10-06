#! /usr/bin/perl -w
#
# fetchconfig - Retrieving configuration for multiple devices
# Copyright (C) 2006 Everton da Silva Marques
#
# fetchconfig is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# fetchconfig is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with fetchconfig; see the file COPYING. If not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301 USA.
#
# $Id: fetchconfig.pl,v 1.2 2006/06/22 14:48:13 evertonm Exp $

use strict;
use fetchconfig::Logger;
use fetchconfig::model::Detector;

sub basename {
    my ($path) = @_;

    my @list;

    if ($^O eq 'MSWin32') {
	@list = split /\\/, $path;
    }
    else {
	@list = split /\//, $path;
    }

    pop @list;
}

my $me = basename($0);

my $log = fetchconfig::Logger->new({ prefix => $me });

my @device_file_list;

foreach (@ARGV) {
    if (/^-devices=(.+)$/) {
	push @device_file_list, $1;
	next;
    }
    $log->error("unexpected argument: $_");
    &usage;
    die;
}

if (@device_file_list < 1) {
    $log->error("at least one device list file is required");
    &usage;
    die;
}

fetchconfig::model::Detector->init($log);

foreach (@device_file_list) {
    &load_device_list($_);
}

$log->info("done");

exit;

sub usage {
    warn "usage: $me -devices=file\n";
}

sub load_device_list {
    my ($filename) = @_;
    
    local *IN;
    
    if (!open(IN, "<$filename")) {
	$log->error("could not read device list: $filename: $!");
	return;
    }
    
    $log->debug("loading device list: $filename");

    my $line_num = 0;
    
    while (<IN>) {
	chomp;

	++$line_num;

	#$log->debug("[$line_num] $_");

	next if (/^\s*(#|$)/);

        fetchconfig::model::Detector->parse($filename, $line_num, $_);
    }
		 
    close IN;
}
