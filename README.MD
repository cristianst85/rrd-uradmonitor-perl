# rrd-uradmonitor-perl

Perl scripts to fetch data from an uRADMonitor device, store it into a RRD database and generate some nice graphs that can be accessed from a web page.
 
The radiation values are stored in the database in counts per minute (cpm) but they are converted to microsieverts per hour (uSv/h) when the graphs are created. The conversion is done using the appropriate factor for the detector present in the device.
 
The pressure graph is generated only if the device has a pressure sensor. The detection is based on the values supplied in JSON.

## Requirements

- A Linux machine running a web server;
- RRDtool and Perl, including additional libraries (shared RRD Perl module, perl-JSON, perl-Time-Piece);
- An [uRADMonitor](http://www.uradmonitor.com/) device model A or A2 with firmware version 110 or newer.
 
## Installation

Put ```rrd_uradmonitor.pl``` script into ```/usr/local/bin``` directory.

Make it executable by running the following command:

```bash
chmod 755 /usr/local/bin/rrd_uradmonitor.pl
```

Localize the settings defined at the beginning of the script.

```perl
# Define your domain name or leave it empty.
# This will be appended to graphs watermark.
my $MY_DOMAIN = ':: www.mydomain.com';

# Define paths
my $RRD_DATABASE_PATH = "/var/lib/rrd/radiation.rrd";
my $RRD_GRAPHS_DIR_PATH = "/srv/www/htdocs/radiation/images";

# Define JSON url (e.g.: http://192.168.0.2/j)
my $JSON_URL = '';
```

Create the directories defined by ```$RRD_DATABASE_PATH```, ```$RRD_GRAPHS_DIR_PATH```.

Test the script by running the following command:

```bash
/usr/local/bin/rrd_uradmonitor.pl
```

On the first execution of the script the RRD database will be created and you should see something like this:

```
Radiation: 20 cpm (0.2 uSv/h)
Temperature: 37 C
Pressure: 100802 Pa
Creating RRD database...
Updating database...
Creating graphs...
```

Schedule the script to run at one minute interval using crontab. Add the following lines to ```/etc/crontab```:

```bash
# uRADMonitor script
*/1 * * * * root /usr/local/bin/rrd_uradmonitor.pl > /dev/null 2>&1
```

## Viewing the graphs

Put ```radiation.cgi``` script into the ```/srv/www/htdocs/radiation``` directory.
 
Make it executable by running the following command:

```bash
chmod 755 /srv/www/htdocs/radiation/radiation.cgi
```
	
Adjust the settings defined at the beginning of the script.

```perl
# Define page auto-refresh interval in seconds
my $REFRESH=60;

# Define uRADMonitor device id (e.g.: #10000000)
my $DEVICE_ID = '';
```

If your device doesn't have a pressure sensor you should comment or remove the following line:

```perl
push (@graphs, "pressure");
```

Instruct your web server to handle ```.cgi``` files from ```/srv/www/htdocs/radiation``` directory by creating an ```.htaccess``` file with the following directives:

```apacheconf
AddHandler cgi-script .cgi
Options +ExecCGI
```

Now you should be able to access the page from your browser at:

```
http://your_domain_or_ip/radiation/radiation.cgi
```

If you want you can rename the ```radiation.cgi``` file to ```index.cgi``` so that it can be accessed more simply as ```http://your_domain_or_ip/radiation/```. Also you
need to add one more directive to ```.htaccess``` file:

```apacheconf
DirectoryIndex index.cgi
```

Clicking any of the daily graphs will then display the detailed graphs for that instance, i.e., daily, weekly, monthly and yearly graphs.

## Demo

You can see the live graphs from my uRADMonitor device readings [here](http://www.disruptivesoftware.ro/radiation/).

## License

Released under the MIT License. See the [bundled LICENSE](https://github.com/cristianst85/rrd-uradmonitor-perl/blob/master/LICENSE) file for details.