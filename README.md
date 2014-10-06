fetchconfig
===========

original project from: http://download.savannah.gnu.org/releases/fetchconfig/


INTRODUCTION
============

	fetchconfig is a Perl script for retrieving configuration of
	multiple devices. Cisco IOS and CatOS devices are currently
	supported. The tool has been tested under Linux and Windows.

LICENSE
=======

        fetchconfig - Retrieving configuration for multiple devices
        Copyright (C) 2006 Everton da Silva Marques

        fetchconfig is free software; you can redistribute it and/or
        modify it under the terms of the GNU General Public License as
        published by the Free Software Foundation; either version 2,
        or (at your option) any later version.

        fetchconfig is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

	You should have received a copy of the GNU General Public
	License along with fetchconfig; see the file COPYING. If not,
	write to the Free Software Foundation, Inc., 51 Franklin St,
	Fifth Floor, Boston, MA 02110-1301 USA.

INSTALLATION
============

	1. fetchconfig.pl expects a Perl interpreter at /usr/bin/perl.

	2. fetchconfig.pl requires the Net::Telnet module.

	3. Just unpack the fetchconfig tarball at a suitable
        location. Example:

	[ fetchconfig tarball available at /tmp/fetchconfig-0.0.tar.gz ]

	cd /usr/local
	tar xzf /tmp/fetchconfig-0.0.tar.gz
	ln -s fetchconfig-0.0 fetchconfig

	[ fetchconfig is now available under /usr/local/fetchconfig ]

USAGE
=====

	1. Edit the file "device_table.example" according your needs,
        and save it as "device_table". Example:

	[ fetchconfig available under /usr/local/fetchconfig ]

	cd /usr/local/fetchconfig
	cp device_table.example device_table
	vi device_table

	2. Run fetchconfig.pl, as in the following example:

	[ fetchconfig available under /usr/local/fetchconfig ]

	cd /usr/local/fetchconfig
	./fetchconfig.pl -devices=device_table

	The fetchconfig.pl script will scan the "device_table" file,
	trying to retrieve the configuration for every device, storing
	configuration files under the "repository".

DEVICE TABLE
============

	The device table assigned with '-device=' switch is a text
        file which supports two types of lines:

	1. Default options lines assign default options to a device
        model. The following example adds some default options to the
        "cisco-ios" model:

	#default	model		model-default-options
	#
	default:        cisco-ios       user=backup,pass=fran,enable=jose

	2. Device lines define attributes of every device and
        optionally assign device-specific options. The following
        example define a device named "vpn-gw":

	#model		dev-unique-id	device-host	[device-options]
	#
	cisco-ios       vpn-gw          192.168.0.1     keep=10,changes_only=1

	The dev-unique-id must be:
	a) an unique identifier across all devices;
	b) a valid filesystem's directory name.

OPTIONS
=======

	The CiscoIOS and CiscoCAT modules recognizes the following
	options:

	pass		A mandatory option, specifies the login password.

	user		Specifies the login username. It can be omitted
                        for devices not requiring a login username.

	enable		Mandatory, specifies the enable password.

	timeout		Mandatory, how long to wait for TELNET responses
                        from devices.

	fetch_timeout	Optional. If given, will override the timeout
                        value used to fetch all the configuration lines.
                        It is useful for devices which spend several
                        seconds building the configuration.

	repository	Mandatory, specifies the base directory for
                        saving the configuration files.

	keep		Mandatory, the maximum number of config files
                        to retain for the device. When this limit is
                        reached, the older files are discarded.

	changes_only	Optional. If specified as changes_only=1,
                        only new configurations are saved. Otherwise,
                        configurations are saved whenever the script
                        runs; if not defined as changes_only=1, the
			script might possibly retain multiple identical
			configuration files.

