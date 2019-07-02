#!/usr/bin/perl
#
# The MIT License (MIT)
#
# Copyright (C) 2015-2019, Cristian Stoica.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Name          : rrd_uradmonitor.pl 
# Version       : 0.6.2
# Date          : 2018/11/25
#
# Description   : A Perl script that fetches data from an uRADMonitor
#                 device, stores it into a RRD database and creates
#                 daily, weekly, monthly and yearly graphs.
#
# Git repository available at https://github.com/cristianst85/rrd-uradmonitor-perl
#

use strict;
use warnings;

use Time::Piece;
use RRDs;
use JSON;

my $ERROR = RRDs::error;

# Define your domain name or leave it empty.
# This will be appended to graphs watermark.
my $MY_DOMAIN = ':: www.mydomain.com';

# Define paths
my $RRD_DATABASE_PATH = "/var/lib/rrd/radiation.rrd";
my $RRD_GRAPHS_DIR_PATH = "/srv/www/htdocs/radiation/images";

# Define JSON url (e.g.: http://192.168.0.2/j)
my $JSON_URL = '';

# Temperature offset to calculate air temperature.
# This value is specific for each device model.
my $AIR_TEMPERATURE_OFFSET = -6.0;

# Conversion factors for all devices can be found at
# https://github.com/radhoo/uradmonitor_kit1/blob/master/code/geiger/detectors.cpp

# Define all known detectors and their corresponding factor.
my %DETECTOR_FACTORS = (
	'SBM19'  => '0.001500',
	'SBM20'  => '0.006315',
	'SBM21'  => '0.048000',
	'SI1G'   => '0.006000',
	'SI3BG'  => '0.631578',
	'SI22G'  => '0.001714',
	'SI29BG' => '0.010000',
	'STS5'   => '0.006666'
);

# Temperature/pressure sensor name. There are two sensors 
# used: DS18B20 for model A and BMP180 for model A2.
my $temp_sensor_name = '';

# Device detector factor. This is used to convert from counts 
# per minute (cpm) to microsieverts per hour (uSv/h).
my $detector_factor = 0;

my $usvh = 0;
my $device_has_pressure_sensor = 0;

# Get data from device.
my $json_data = `wget -q -O - "$JSON_URL"`;
my $data_object = from_json($json_data);

my $cpm = $data_object->{'data'}->{'cpm'};
my $temp = $data_object->{'data'}->{'temperature'};
my $pres = $data_object->{'data'}->{'pressure'};
my $device_id = $data_object->{'data'}->{'id'};
my $detector_name = $data_object->{'data'}->{'detector'};

# Normalize detector name by removing dashes.
$detector_name =~ s/-//; 

$detector_factor = $DETECTOR_FACTORS{$detector_name};

if (! defined $detector_factor) {
	die ("Cannot get detector factor. Unknown radiation detector (".$detector_name.").");
}

$usvh = ($cpm * $detector_factor);

if (defined $pres) {
	$device_has_pressure_sensor = 1;
	$temp_sensor_name = 'BMP180 '; # Pad right to keep them nicely aligned.
}
else {
	$temp_sensor_name = 'DS18B20';
	$pres = 0;
}

printf "Radiation: $cpm cpm ($usvh uSv/h)\n";
printf "Temperature: $temp degrees C\n";
printf "Air Temperature: %s degrees C\n", $temp + $AIR_TEMPERATURE_OFFSET;

if ($device_has_pressure_sensor) {
	printf "Pressure: $pres Pa\n";
}

if (! -e "$RRD_DATABASE_PATH") {
	print "Creating RRD database...\n";
	RRDs::create "$RRD_DATABASE_PATH",
		"-s 60",
		"DS:cpm:GAUGE:120:0:U",
		"DS:temp:GAUGE:120:-100:100",
		"DS:pres:GAUGE:120:0:200000",
		"RRA:AVERAGE:0.5:1:1440",
		"RRA:AVERAGE:0.5:5:2016",
		"RRA:AVERAGE:0.5:60:744",
		"RRA:AVERAGE:0.5:720:732",
		"RRA:MAX:0.5:1:1440",
		"RRA:MAX:0.5:5:2016",
		"RRA:MAX:0.5:60:744",
		"RRA:MAX:0.5:720:732";
}	

if ($ERROR = RRDs::error) {
     print "$0: unable to create RRD database $ERROR\n";
}

print "Updating database...\n";
RRDs::update "$RRD_DATABASE_PATH",
	"-t", "cpm:temp:pres",
	"N:$cpm:$temp:$pres";

if ($ERROR = RRDs::error) {
	print "$0: unable to update RRD database $ERROR\n";
}

my $now = Time::Piece->new->strftime('%d/%m/%Y %H:%M:%S (%Z/%z)');
print "Creating graphs...\n";

&create_radiation_graph("radiation", "day", "-1day");
&create_radiation_graph("radiation", "week", "-7day");
&create_radiation_graph("radiation", "month", "-1month");
&create_radiation_graph("radiation", "year", "-1year");
&create_temperature_graph("temperature", "day", "-1day");
&create_temperature_graph("temperature", "week", "-7day");
&create_temperature_graph("temperature", "month", "-1month");
&create_temperature_graph("temperature", "year", "-1year");

if ($device_has_pressure_sensor) {
	&create_pressure_graph("pressure", "day", "-1day");
	&create_pressure_graph("pressure", "week", "-7day");
	&create_pressure_graph("pressure", "month", "-1month");
	&create_pressure_graph("pressure", "year", "-1year");
}

sub create_radiation_graph {
        RRDs::graph "$RRD_GRAPHS_DIR_PATH/$_[0]-$_[1].png",
        "--slope-mode",
        "-s $_[2]", "-e now",
        #"--lazy",
        "-t uRADMonitor #$device_id :: Gamma Radiation",
        "-h", "80", "-w", "600",
        "-l 0",
        "-X 0",
        "-W Graph created at $now $MY_DOMAIN",
        "-a", "PNG",
        "-v uSv/h",
        "DEF:cpm=$RRD_DATABASE_PATH:cpm:AVERAGE",
        "DEF:max=$RRD_DATABASE_PATH:cpm:MAX",
        "CDEF:usvh=cpm,$detector_factor,*",
        "CDEF:usvhmax=max,$detector_factor,*",
        "AREA:usvh#00CCCC:Detector $detector_name",
        "GPRINT:usvh:MAX:Max\\: %5.2lf",
        "GPRINT:usvh:AVERAGE:Avg\\: %5.2lf",
        "GPRINT:usvh:MIN:Min\\: %5.2lf",
        "GPRINT:usvh:LAST:Current\\: %5.2lf uSv/h",
        "AREA:usvhmax#80808088:Maximum values\\n";

        if ($ERROR = RRDs::error) {
                print "$0: unable to create $_[0] graph $ERROR\n";
        }
}

sub create_temperature_graph {
        RRDs::graph "$RRD_GRAPHS_DIR_PATH/$_[0]-$_[1].png",
        "--slope-mode",
        "-s $_[2]", "-e now",
        #"--lazy",
        "-t uRADMonitor #$device_id :: Temperature",
        "-h", "80", "-w", "600",
        "-l 0",
        "-W Graph created at $now $MY_DOMAIN",
        "-a", "PNG",
        "-v degrees C",
        "DEF:temp=$RRD_DATABASE_PATH:temp:AVERAGE",
        "CDEF:air_temp=temp,$AIR_TEMPERATURE_OFFSET,+",
        "LINE:temp#FF0000:Sensor $temp_sensor_name ", # Pad right with an extra space.
        "GPRINT:temp:MAX:Max\\: %2.1lf",
        "GPRINT:temp:AVERAGE:Avg\\: %2.1lf",
        "GPRINT:temp:MIN:Min\\: %2.1lf",
        "GPRINT:temp:LAST:Current\\: %2.1lf degrees C\\n",
        "LINE:air_temp#7F00FF:Air Temperature",
        "GPRINT:air_temp:MAX:Max\\: %2.1lf",
        "GPRINT:air_temp:AVERAGE:Avg\\: %2.1lf",
        "GPRINT:air_temp:MIN:Min\\: %2.1lf",
        "GPRINT:air_temp:LAST:Current\\: %2.1lf degrees C\\n";

        if ($ERROR = RRDs::error) {
                print "$0: unable to create $_[0] graph $ERROR\n";
        }
}

sub create_pressure_graph {
        RRDs::graph "$RRD_GRAPHS_DIR_PATH/$_[0]-$_[1].png",
        "--slope-mode",
        "-s $_[2]", "-e now",
        #"--lazy",
        "-t uRADMonitor #$device_id :: Pressure",
        "-h", "80", "-w", "600",
        "-l 0",
        "-W Graph created at $now $MY_DOMAIN",
        "-a", "PNG",
        "-v Pa",
        "--alt-autoscale-max",
        "--alt-y-grid",
        "-l 95000",
        "DEF:pres=$RRD_DATABASE_PATH:pres:AVERAGE",
        "AREA:101325#0000FF22:Standard Atmosphere\\: 101325 Pa (1 atm)\\n",
        "LINE:pres#666666:Sensor $temp_sensor_name",
        "GPRINT:pres:MAX:Max\\: %2.1lf",
        "GPRINT:pres:AVERAGE:Avg\\: %2.1lf",
        "GPRINT:pres:MIN:Min\\: %2.1lf",
        "GPRINT:pres:LAST:Current\\: %2.1lf Pa\\n";

        if ($ERROR = RRDs::error) {
                print "$0: unable to create $_[0] graph $ERROR\n";
        }
}
