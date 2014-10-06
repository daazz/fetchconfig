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
# $Id: Abstract.pm,v 1.2 2006/06/22 14:48:13 evertonm Exp $

package fetchconfig::model::Abstract; # fetchconfig/model/Abstract.pm

use strict;
use warnings;
use File::Compare;

####################################
# Implement model::Abstract - Begin
#

sub label {
    die "model::Abstract->label: SPECIALIZE ME";
}

sub new {
    my ($class, $log) = @_;

    my $self = {
	log             => $log,
	default_options => {}
    };

    bless $self, $class;
}

sub fetch {
    my ($self, $file, $line_num, $line, $dev_id, $dev_host, $dev_opt_tab) = @_;

    die "model::Abstract->fetch: SPECIALIZE ME";
}

#
# Implement model::Abstract - End
##################################

sub log_debug {
    my ($self, $msg) = @_;

    $self->{log}->debug($self->label . ": " . $msg);
}

sub log_error {
    my ($self, $msg) = @_;

    $self->{log}->error($self->label . ": " . $msg);
}

sub parse_options {
    my ($self, $label, $file, $line_num, $line, $opt_tab_ref, @options) = @_;

    foreach (@options) {
	foreach (split /,/) {
	    if (/^([^=]+)=([^=]*)$/) {
		$opt_tab_ref->{$1} = $2;
		next;
	    }
	    $self->log_error("bad $label option '$_' at file=$file line=$line_num: $line");
	}
    }
}

sub dump_options {
    my ($self, $label, $opt_tab_ref) = @_;

    while (my ($name, $value) = each %$opt_tab_ref) {
	$self->log_debug("$label option: $name=$value");
    }
}

sub default_options {
    my ($self, $file, $line_num, $line, @model_default_options) = @_;

    $self->parse_options('default',
			 $file, $line_num, $line,
			 $self->{default_options},
			 @model_default_options);

    #$self->dump_options('default', $self->{default_options});
}

sub dev_option {
    my ($self, $dev_opt_tab, $opt_name) = @_;

    my $value = $dev_opt_tab->{$opt_name};

    return $value if defined($value);

    $self->{default_options}->{$opt_name};
}

sub get_timestr {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    ++$mon;
    ($year, $mon, $mday, $hour, $min, $sec);
}

sub dump_config {
    my ($self, $dev_id, $dev_opt_tab, $conf_ref) = @_;

    my $dev_repository = $self->dev_option($dev_opt_tab, "repository");

    my ($year, $mon, $day, $hour, $min, $sec) = get_timestr;

    my $dir_path = sprintf("$dev_repository/%04d%02d/%04d%02d%02d/$dev_id",
			   $year, $mon, $year, $mon, $day);

    if (! -d $dir_path) {
	my $mk;
	if ($^O eq 'MSWin32') {
	    my $path = $dir_path;
	    $path =~ tr/\//\\/;
	    $mk = "mkdir $path";
	}
	else {
	    $mk = "mkdir -p $dir_path";
	}

	my $ret = system $mk;
	if ($ret) {
	    $self->log_error("could not create dir: $mk: ret=$ret: $!");
	    return undef;
	}
    }

    my $file = sprintf("${dev_id}.run.%04d%02d%02d.%02d%02d%02d",
		       $year, $mon, $day, $hour, $min, $sec);

    my $file_path = "$dir_path/$file";

    local *OUT;

    if (!open(OUT, ">$file_path")) {
	$self->log_error("could not write dump file: $file_path: $!");
	return undef;
    }

    {
	$, = "\n";
	print OUT @$conf_ref;
    }

    if (!close(OUT)) {
	$self->log_error("could not close dump file: $file_path: $!");
	return undef;
    }

    ($dir_path, $file);
}

sub find_latest {
    my ($self, $dev_id, $dev_opt_tab) = @_;

    my $dev_repository = $self->dev_option($dev_opt_tab, "repository");

    my %dir_tab;

    if ($self->scan_dir(\%dir_tab, $dev_id, $dev_repository)) {
	$self->log_error("latest config not found - error scanning repository");
	return undef;
    }

    my @files = sort { $b cmp $a } keys %dir_tab;

    if (@files < 1) {
	$self->log_error("there is no latest config");
	return undef;
    }

    my $latest_file = $files[0];
    my $latest_dir = $dir_tab{$latest_file};

    ($latest_dir, $latest_file);
}

sub scan_dir {
    my ($self, $dir_tab_ref, $dev_id, $dir_path) = @_;

    my $error = 0;

    local *DIR;

    if (!opendir(DIR, $dir_path)) {
	$self->log_error("could not open dir: $dir_path: $!");
	return 1;
    }

    foreach (readdir DIR) {
	my $file = "$dir_path/$_";

	if (-f $file) {
	    my $pattern = ${dev_id} . '\.run\.';
	    next unless ($_ =~ /^$pattern/);
	
	    if (exists($dir_tab_ref->{$_})) {
		$self->log_error("ugh: duplicate backup file: $_");
		return 1;
	    }
	    $dir_tab_ref->{$_} = $dir_path;
	
	    next;
        }

        next if (/^\./);

	if ($self->scan_dir($dir_tab_ref, $dev_id, $file)) {
	    $error = 1;
	    last;
	}
    }

    if (!closedir(DIR)) {
	$self->log_error("could not close dir: $dir_path: $!");
	return 1;
    }

    $error;
}

sub config_equal {
    my ($self, $prev_dir, $prev_file, $curr_dir, $curr_file) = @_;

    my $prev_path = "$prev_dir/$prev_file";
    my $curr_path = "$curr_dir/$curr_file";

    my $result = compare($prev_path, $curr_path);
    if ($result < 0) {
	$self->log_error("failure comparing $prev_path to $curr_path");
    }

    # -1: error: return false, in order to keep the newer version
    # 0: equal: return true, in order to allow discarding the newer version
    # 1: distinct: return false, in order to keep the newer version

    !$result;
}

sub prune_dir_tree {
    my ($self, $depth, $dir) = @_;

    #$self->log_debug("prunning depth=$depth: $dir");

    return if ($depth < 1);

    if (rmdir $dir) {
	my @labels = split /\//, $dir;

	pop @labels;

	my $parent = join '/', @labels;

	$self->prune_dir_tree($depth - 1, $parent);
	
	return;
    }

    #$self->log_debug("could not rmdir: $dir: $!");
}

sub config_discard {
    my ($self, $config_dir, $config_file) = @_;

    my $path = "$config_dir/$config_file";

    #$self->log_debug("discarding: $path");

    if (unlink($path) != 1) {
	$self->log_error("could not discard config file: $path; $!");
	return;
    }

    $self->prune_dir_tree(3, $config_dir);
}

sub purge_ancient {
    my ($self, $dev_id, $dev_opt_tab) = @_;

    my $dev_keep = $self->dev_option($dev_opt_tab, "keep");
    if (!defined($dev_keep)) {
	$self->log_error("unspecified maximum of config files to keep");
	return;
    }

    my $dev_repository = $self->dev_option($dev_opt_tab, "repository");

    my %dir_tab;

    if ($self->scan_dir(\%dir_tab, $dev_id, $dev_repository)) {
	$self->log_error("could not load full device config list - error scanning repository");
	return;
    }

    my @files = keys %dir_tab;

    my $expired = @files - $dev_keep;

    return if ($expired < 1);

    my @sorted = sort @files;

    for (my $i = 0; $i < $expired; ++$i) {
	my $file = $sorted[$i];
	my $dir = $dir_tab{$file};

	$self->log_debug("expiring: $dir/$file");

	$self->config_discard($dir, $file);
    }
}

1;
