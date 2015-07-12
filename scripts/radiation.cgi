#!/usr/bin/perl
#
# The MIT License (MIT)
#
# Copyright (C) 2015, Cristian Stoica.
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
# Name          : radiation.cgi
# Version       : 0.4.0
# Date          : 2015/07/16
#
# Description   : A Perl script that generates a simple web page to view the 
#                 graphs created from the data stored in the RRD database.
#
# Git repository available at https://github.com/cristianst85/rrd-uradmonitor-perl
#

use strict;
use warnings;

# Define page auto-refresh interval in seconds
my $REFRESH=60;

# Define uRADMonitor device id (e.g.: #10000000)
my $DEVICE_ID = '';

my $srv_name;
my $description;
my $name = '';
my $graph;

my @graphs;

# Define graphs to display.
push (@graphs, "radiation");
push (@graphs, "temperature");

# Comment/remove the line below if the device has no pressure sensor.
push (@graphs, "pressure");

# Get the server name or put some other description here.
$srv_name = $ENV{'SERVER_NAME'};

# Get url parameters
my @params = split(/&/, $ENV{'QUERY_STRING'});
my $param_name = '';
my $param_value = '';
foreach my $i (@params) {
	($param_name, $param_value) = split(/=/, $i);
	if ($param_name eq 'trend') {
		$name = $param_value;
	}
}

if ($name eq '') {
	$description = "summary :: last 24 hours";
}
else {
	if ($name eq 'radiation') {
		$description = "gamma radiation";
	}
	else {
		$description = $name;
	}
}

print "Content-type: text/html;\n\n";
print <<END
<html>
<head>
  <title>$srv_name :: radiation monitoring :: $description</title>
  <meta http-eqiv="Refresh" content="$REFRESH" />
  <meta http-eqiv="Cache-Control" content="no-cache" />
  <meta http-eqiv="Pragma" content="no-cache" />
  <style>
    body { 
	font-family: Verdana, Tahoma, Arial, Helvetica;
	font-size: 12px;
	margin-top: 5px;
   }
   img {
	margin-top: 1px;
   }
   .header {
	font-size: 16pt;
	font-weight: 900;
   }
  </style>
</head>
<body>
<span class='header'>uRADMonitor $DEVICE_ID :: $description</span>
<br />
END
;
if ($name eq '') {
	print "<br />";
	print "Daily Graphs (60 seconds averages)";
	print "<br />";
	foreach $graph (@graphs) {
		print "<a href='?trend=$graph'><img src='images/$graph-day.png'></a>";
		print "<br />";
	}
	# You can add here some extra info about this page here.
}
else {
	print <<END
	<br />
	Daily Graph (1 minute averages)
	<br />
	<img src='images/$name-day.png'>
	<br /><br />
	Weekly Graph (5 minutes averages)
	<br />
	<img src='images/$name-week.png'>
	<br /><br />
	Monthly Graph (1 hour averages)
	<br />
	<img src='images/$name-month.png'>
	<br /><br />
	Yearly Graph (12 hours averages)
	<br />
	<img src='images/$name-year.png'>
END
;
}
print <<END
<br /><br />
</body>
</html>
END
;