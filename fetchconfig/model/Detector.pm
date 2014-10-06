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
# $Id: Detector.pm,v 1.14 2008/01/21 19:55:04 evertonm Exp $

package fetchconfig::model::Detector; # fetchconfig/model/Detector.pm

use strict;
use warnings;
use fetchconfig::model::CiscoIOS;
use fetchconfig::model::CiscoCAT;
use fetchconfig::model::FortiGate;
use fetchconfig::model::ProCurve;
use fetchconfig::model::Parks;
use fetchconfig::model::Riverstone;
use fetchconfig::model::Dell;

my $logger;
my %model_table;
my %dev_id_table;

sub parse {
    my ($class, $file, $num, $line) = @_;

    if (ref $class) { die "class method called as object method"; }
    unless (@_ == 4) { die "usage: $class->parse(\$logger, \$line_num, \$line)"; }

    #$logger->debug("Detector->parse: $line");

    if ($line =~ /^\s*default:/) {
	#
        ## global        model           options
        # default:       cisco-ios       user=backup,pass=san,enable=san
	#
	if ($line !~ /^\s*(\S+)\s+(\S+)\s+(\S.*)$/) {
	    $logger->error("unrecognized default at file=$file line=$num: $line");
	    return;
	}

	my @row = ($1, $2, $3);
	my $model_label = shift @row;

	$model_label = $row[0];
	my $mod = $model_table{$model_label};
	if (ref $mod) {
	    shift @row;
	    $mod->default_options($file, $num, $line, @row);
	    return;
	}

	$logger->error("unknown model '$model_label' at file=$file line=$num: $line");

	return;
    }

    #
    ## model         dev-unique-id   hostname        device-specific-options
    #cisco-ios       spo2            10.0.0.1 user=backup,pass=san,enable=fran
    #

    if ($line !~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s*(.*)$/) {
	$logger->error("unrecognized device at file=$file line=$num: $line");
	return;
    }

    my @row = ($1, $2, $3, $4);
    my $model_label = shift @row;

    my $mod = $model_table{$model_label};
    if (ref $mod) {
	my $dev_id = shift @row;

	my $dev_id_linenum = $dev_id_table{$dev_id};
	if (defined($dev_id_linenum)) {
	    $logger->error("duplicated dev_id=$dev_id at file=$file line=$num: $line (previous at line $dev_id_linenum)");
	    return;
	}

	$dev_id_table{$dev_id} = $num;

	my $dev_host = shift @row;

	my $dev_opt_tab = {};

	$mod->parse_options("dev=$dev_id",
			    $file, $num, $line,
			    $dev_opt_tab,
			    @row);

	my ($latest_dir, $latest_file);

	#
	# "changes_only" is true: configuration is saved only when changed
	# "changes_only" is false: configuration is always saved
	#
	my $dev_changes_only = $mod->dev_option($dev_opt_tab, "changes_only");
	if ($dev_changes_only) {
	    ($latest_dir, $latest_file) = $mod->find_latest($dev_id, $dev_opt_tab);
	}

	my $fetch_ts_start = time;
	$logger->info("dev=$dev_id host=$dev_host: retrieving config at " . scalar(localtime($fetch_ts_start)));

	my ($config_dir, $config_file) = $mod->fetch($file, $num, $line, $dev_id, $dev_host, $dev_opt_tab);

	my $fetch_elap = time - $fetch_ts_start;
	$logger->info("dev=$dev_id host=$dev_host: config retrieval took $fetch_elap secs");

	return unless defined($config_dir);

	if (defined($latest_dir)) {
	    if ($mod->config_equal($latest_dir, $latest_file, $config_dir, $config_file)) {
		$logger->debug("dev=$dev_id host=$dev_host: config unchanged since last run");
		$mod->config_discard($config_dir, $config_file);
	    }
	}

	$mod->purge_ancient($dev_id, $dev_opt_tab);

	return;
    }

    $logger->error("unknown model '$model_label' at file=$file line=$num: $line");
}

sub register {
    my ($class, $mod) = @_;

    $logger->debug("registering model: " . $mod->label);

    $model_table{$mod->label} = $mod;
}

sub init {
    my ($class, $log) = @_;

    $logger = $log;

    $class->register(fetchconfig::model::CiscoIOS->new($log));
    $class->register(fetchconfig::model::CiscoCAT->new($log));
    $class->register(fetchconfig::model::FortiGate->new($log));
    $class->register(fetchconfig::model::ProCurve->new($log));
    $class->register(fetchconfig::model::Parks->new($log));
    $class->register(fetchconfig::model::Riverstone->new($log));
    $class->register(fetchconfig::model::Dell->new($log));
}

1;
