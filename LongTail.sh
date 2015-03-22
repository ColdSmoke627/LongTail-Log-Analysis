#!/bin/sh 

############################################################################
# This is my crontab entry
# 59 * * * * /usr/local/etc/LongTail.sh >> /tmp/LongTail.sh.out 2>> /tmp/LongTail.sh.out
#
# You need to have /usr/local/etc/whois.pl installed also.  Sure, I could 
# have a faster mysql backend, but I don't NEED it.
#
# I am assuming your /var/log/messages file is really called messages, or 
# messages<something>.  .gz files are ok too.
#
# I am assuming your /var/log/httpd/access_file file is really called 
# access_file, or access_file<something>.  .gz files are ok too.
#
# you can also call this program with a hostname (from the messages files)
# so that you can analyze different hosts separately, each in 
# /honey/<HOSTNAME>/ directories.
#
# This is not fully tested yet :-)
#
############################################################################
# This reads /usr/local/etc/LongTail.config.  If your file isn't there,
# then this is the only place you need to edit.

function read_local_config_file {
	if [ -e "/usr/local/etc/LongTail.config" ] ; then
		. /usr/local/etc/LongTail.config
	fi
}

############################################################################
# Assorted Variables, you should probably edit /usr/local/etc/LongTail.config
# though...  Otherwise when you install a new version you'll lose your
# configuration
#
function init_variables {
	# Do you want Pretty graphs using jpgraph?  Set this to 1
	# http://jpgraph.net/  JpGraph - Most powerful PHP-driven charts
	GRAPHS=1

	# Do you want debug output?  Set this to 1
	DEBUG=0
	
	# Do you want ssh analysis?  Set this to 1
	DO_SSH=1
	
	# Do you want httpd analysis?  Set this to 1
	DO_HTTPD=1
	
	# Do we obfuscate/rename the IP addresses?  You might want to do this if
	# you are copying your reports to a public site.
	# OBFUSCATE_IP_ADDRESSES=1 will hide addresses
	# OBFUSCATE_IP_ADDRESSES=0 will NOT hide addresses
	OBFUSCATE_IP_ADDRESSES=0
	
	# OBFUSCATE_URLS=1 will hide URLs in the http report
	# OBFUSCATE_URLS=0 will NOT hide URLs in the http report
	# This may not work properly yet.
	OBFUSCATE_URLS=0
	
	# These are the search strings from the "LogIt" function in auth-passwd.c
	# and are used to figure out which ports are being brute-forced.
	# The code for PASSLOG2222 has not yet been written.
	PASSLOG="PassLog"
	PASSLOG2222="Pass2222Log"
	
	# Where are the scripts we need to run?
	SCRIPT_DIR="/usr/local/etc/"
	if [ ! -d $SCRIPT_DIR ] ; then
		echo "Can not find SCRIPT_DIR: $SCRIPT_DIR, exiting now"
		exit
	fi
	
	# Where do we put the reports?
	HTML_DIR="/var/www/html/honey/"
	if [ ! -d $HTML_DIR ] ; then
		echo "Can not find HTML_DIR: $HTML_DIR, exiting now"
		exit
	fi
	
	#Where is the messages file?
	PATH_TO_VAR_LOG="/var/log/"
	
	#Where is the apache access_log file?
	PATH_TO_VAR_LOG_HTTPD="/var/log/httpd/"
	
	# This is for my personal debugging, just leave them
	# commented out if you aren't me.
	#PATH_TO_VAR_LOG="/home/wedaa/source/LongTail/var/log/"
	#PATH_TO_VAR_LOG_HTTPD="/home/wedaa/source/LongTail/var/log/httpd/"
	
	############################################################################
	# You don't need to edit after this.
	#
	TODAY_AT_START_OF_RUNTIME=`date`
	YEAR=`date +%Y`
	HOUR=`date +%H` # This is used at the end of the program but we want to know it NOW
	YEAR_AT_START_OF_RUNTIME=`date +%Y`
	MONTH_AT_START_OF_RUNTIME=`date +%m`
	DAY_AT_START_OF_RUNTIME=`date +%d`
}

############################################################################
# Lets make sure we can write to the directory
#
function is_directory_good {
	if [ ! -d $1  ] ; then
        	echo "$1 is not a directory, exiting now "
		exit
	fi
	if [ ! -w $1  ] ; then
        	echo "I can't write to /tmp", exiting now
		exit
	fi
}
############################################################################
# Change the date in index.shtml
#
function change_date_date_in_index {
	DATE=`date`
	sed -i "s/updated on..*$/updated on $DATE/" $1/index.shtml
	sed -i "s/updated on..*$/updated on $DATE/" $1/index-long.shtml
	sed -i "s/updated on..*$/updated on $DATE/" $1/graphics.shtml
}
	
############################################################################
# Make a proper HTML header for assorted columns
#
function make_header {
	# first argument, the full path including the filename you want to write to
	# second argument, the title of the web page
	# Third argument, text for description
	# Other arguments are the column headers
	# NOTE: This destroys $MAKE_HEADER_FILENAME before adding to it.
	MAKE_HEADER_DATE=`date`
	if [ "$#" == "0" ]; then
		echo "You forgot to pass arguments, exiting now"
		exit 1
	fi
	MAKE_HEADER_FILENAME=$1
	#echo "filename is $MAKE_HEADER_FILENAME"
	touch $MAKE_HEADER_FILENAME
	if [ ! -w $MAKE_HEADER_FILENAME ] ; then
		echo "Can't write to $MAKE_HEADER_FILENAME, exiting now"
		exit
	fi
	shift
	
	TITLE=$1
	shift
	
	DESCRIPTION=$1
	shift

	echo "<HTML><!--HEADERLINE -->" > $MAKE_HEADER_FILENAME
	echo "<HEAD><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<META http-equiv=\"pragma\" content=\"no-cache\"><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<TITLE>LongTail Log Analysis $TITLE</TITLE> <!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<style> /* HEADERLINE */ " >> $MAKE_HEADER_FILENAME
	echo ".td-some-name /* HEADERLINE */ " >> $MAKE_HEADER_FILENAME
	echo "{ /* HEADERLINE */ " >> $MAKE_HEADER_FILENAME
	echo "  white-space:nowrap; /* HEADERLINE */ " >> $MAKE_HEADER_FILENAME
	echo "  vertical-align:top; /* HEADERLINE */ " >> $MAKE_HEADER_FILENAME
	echo "} /* HEADERLINE */ " >> $MAKE_HEADER_FILENAME
	echo "</style> <!--HEADERLINE --> " >> $MAKE_HEADER_FILENAME

	echo "</HEAD><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<BODY BGCOLOR=#00f0FF><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<!--#include virtual="/honey/header.html" --> <!--HEADERLINE --> " >> $MAKE_HEADER_FILENAME
	echo "<H1>LongTail Log Analysis</H1><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<H3>$TITLE</H3><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<P>$DESCRIPTION <!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<P>Created on $MAKE_HEADER_DATE<!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	
	if [ $OBFUSCATE_IP_ADDRESSES -gt 0 ] ; then
		echo "<P>IP Addresses have been obfuscated to hide the guilty. <!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
		echo "ALL IP addresses have been reset to end in .127. <!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	fi

	echo "<TABLE border=1><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<TR><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	while (( "$#" )); do
		echo "<TH>$1</TH><!--HEADERLINE -->" >>$MAKE_HEADER_FILENAME
		shift
	done
	echo "</TR><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
}

############################################################################
# Make a proper HTML footer for assorted columns
#
function make_footer {
	# One argument, the full path including the filename you want to write to
	if [ "$#" == "0" ]; then
		echo "You forgot to pass arguments, exiting now"
		exit 1
	fi
	MAKE_FOOTER_FILENAME=$1
	#echo "filename is $MAKE_FOOTER_FILENAME"
	touch $MAKE_FOOTER_FILENAME
	if [ ! -w $MAKE_FOOTER_FILENAME ] ; then
		echo "Can't write to $MAKE_FOOTER_FILENAME, exiting now"
		exit
	fi
	echo "" >> $MAKE_FOOTER_FILENAME
	echo "</TABLE><!--HEADERLINE -->" >> $MAKE_FOOTER_FILENAME
	echo "<!--#include virtual="/honey/footer.html" --> <!--HEADERLINE --> " >> $MAKE_FOOTER_FILENAME
	echo "</BODY><!--HEADERLINE -->" >> $MAKE_FOOTER_FILENAME
	echo "</HTML><!--HEADERLINE -->" >> $MAKE_FOOTER_FILENAME
	if [ $OBFUSCATE_IP_ADDRESSES -gt 0 ] ; then
		hide_ip $1
	fi
}


############################################################################
# Obfuscate any IP addresses found by setting the last octet to 128
# I am assuming that any address in a class C address is controlled
# or owned by whoever owns the Class C
#
# This way the report doesn't name any single user, but blames the
# owner of the Class C range.
#
function hide_ip {
	# One argument, the full path including the filename you want to write to
	if [ "$#" == "0" ]; then
		echo "You forgot to pass arguments, exiting now"
		exit 1
	fi
	sed -i -r 's/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)[0-9]{1,3}/\1127/g' $1
}


############################################################################
# Count ssh attacks and modify $HTML_DIR/index.html
#
# Called as count_ssh_attacks $HTML_DIR $PATH_TO_VAR_LOG "messages*"
#
function count_ssh_attacks {
	if [ $DEBUG  == 1 ] ; then echo "DEBUG-in count_ssh_attacks now" ; fi
	TMP_HTML_DIR=$1
	PATH_TO_VAR_LOG=$2
	MESSAGES=$3

	ORIGINAL_DIRECTORY=`pwd`

	TMP_DATE=`date +"%Y-%m-%d"`
	TMP_YEAR=`date +%Y`
	TMP_MONTH=`date +%m`
	TMP_DAY=`date +%d`
	#
	# Lets make sure we have one for today and this month and this year
	TMP_DIR="$TMP_HTML"
	if [ ! -d $TMP_DIR  ] ; then mkdir $TMP_DIR ; chmod a+rx $TMP_DIR; fi
	TMP_DIR="$TMP_HTML_DIR/historical"
	if [ ! -d $TMP_DIR  ] ; then mkdir $TMP_DIR ; chmod a+rx $TMP_DIR; fi
	TMP_DIR="$TMP_HTML_DIR/historical/$TMP_YEAR"
	if [ ! -d $TMP_DIR  ] ; then mkdir $TMP_DIR ; chmod a+rx $TMP_DIR; fi
	TMP_DIR="$TMP_HTML_DIR/historical/$TMP_YEAR/$TMP_MONTH"
	if [ ! -d $TMP_DIR  ] ; then mkdir $TMP_DIR ; chmod a+rx $TMP_DIR; fi
	TMP_DIR="$TMP_HTML_DIR/historical/$TMP_YEAR/$TMP_MONTH/$TMP_DAY"
	if [ ! -d $TMP_DIR  ] ; then mkdir $TMP_DIR ; chmod a+rx $TMP_DIR; fi
	#
	# Why did I add this line?
	#
	if [ ! -e $TMP_HTML_DIR/historical/$TMP_YEAR/$TMP_MONTH/$TMP_DAY/current-raw-data.gz ] ; then
		echo "" |gzip -c > $TMP_HTML_DIR/historical/$TMP_YEAR/$TMP_MONTH/$TMP_DAY/current-raw-data.gz
		chmod a+r $TMP_HTML_DIR/historical/$TMP_YEAR/$TMP_MONTH/$TMP_DAY/current-raw-data.gz
	fi


	#
	# TODAY
	#
	cd $PATH_TO_VAR_LOG
	if [ "x$HOSTNAME" == "x/" ] ;then
		TODAY=`$SCRIPT_DIR/catall.sh $PATH_TO_VAR_LOG/$MESSAGES |grep ssh |grep "$TMP_DATE" | grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |egrep Password|wc -l`
	else
		TODAY=`$SCRIPT_DIR/catall.sh $PATH_TO_VAR_LOG/$MESSAGES |grep ssh |awk '$2 == "'$HOSTNAME'" {print}'  |grep "$TMP_DATE" | grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |egrep Password|wc -l`
	fi
	echo $TODAY > $TMP_HTML_DIR/current-attack-count.data

	#
	# THIS MONTH
	#
	cd $TMP_HTML_DIR/historical/
	TMP=0
	for FILE in  `find $TMP_YEAR/$TMP_MONTH -name current-attack-count.data` ; do
		COUNT=`cat $FILE`
		(( TMP += $COUNT ))
	done
	THIS_MONTH=`expr $TMP + $TODAY`
	# OK, this may not be 100% secure, but it's close enough for now
	if [ $DEBUG  == 1 ] ; then echo "DEBUG this month statistics" ; fi
	#
	# So there's a problem if it's the first day of the month and there's
	# No real statistics yet.
	#
	TMPFILE=$(mktemp /tmp/output.XXXXXXXXXX)
	if [ -e $TMP_YEAR/$TMP_MONTH ] ; then 
		cat $TMP_YEAR/$TMP_MONTH/*/current-attack-count.data|perl -e 'use List::Util qw(max min sum); @a=();while(<>){$sqsum+=$_*$_; push(@a,$_)}; $n=@a;$s=sum(@a);$a=$s/@a;$m=max(@a);$mm=min(@a);$std=sqrt($sqsum/$n-($s/$n)*($s/$n));$mid=int @a/2;@srtd=sort @a;if(@a%2){$med=$srtd[$mid];}else{$med=($srtd[$mid-1]+$srtd[$mid])/2;}; $n; print "MONTH_COUNT=$n\nMONTH_SUM=$s\nMONTH_AVERAGE=$a\nMONTH_STD=$std\nMONTH_MEDIAN=$med\nMONTH_MAX=$m\nMONTH_MIN=$mm";'  > $TMPFILE
		# Now we "source" the script to set environment varaibles we use later
		. $TMPFILE
		rm $TMPFILE
		# Now we "clean up" the average and STD deviation
		MONTH_AVERAGE=`printf '%.2f' $MONTH_AVERAGE`
		MONTH_STD=`printf '%.2f' $MONTH_STD`
	else
		MONTH_COUNT=1
		MONTH_SUM=$TODAY
		MONTH_AVERAGE=$TODAY
		MONTH_STD=0
		MONTH_MEDIAN=$TODAY
		MONTH_MAX=$TODAY
		MONTH_MIN=$TODAY
		#MONTH_AVERAGE=`printf '%.2f' 0`
		MONTH_STD=`printf '%.2f' 0`
	fi


	#
	# LAST MONTH
	#
	cd $TMP_HTML_DIR/historical/
#
# Gotta fix this for the year boundary
#
	TMP_LAST_MONTH=`date "+%m" --date="last month"`
	TMP_LAST_MONTH_YEAR=`date "+%Y" --date="last month"`
	TMP=0
	for FILE in  `find $TMP_LAST_MONTH_YEAR/$TMP_LAST_MONTH -name current-attack-count.data` ; do
		COUNT=`cat $FILE`
		(( TMP += $COUNT ))
	done
	LAST_MONTH=$TMP
	# OK, this may not be 100% secure, but it's close enough for now
	if [ $DEBUG  == 1 ] ; then echo "DEBUG Last month statistics" ; fi
	#
	# So there's a problem if it's the first day of the month and there's
	# No real statistics yet.
	#
	TMPFILE=$(mktemp /tmp/output.XXXXXXXXXX)
	#
	# Gotta do the date calculation to figure out "When" is last month
	#
	if [ -d $TMP_LAST_MONTH_YEAR/$TMP_LAST_MONTH/ ] ; then 
		cat $TMP_LAST_MONTH_YEAR/$TMP_LAST_MONTH/*/current-attack-count.data|perl -e 'use List::Util qw(max min sum); @a=();while(<>){$sqsum+=$_*$_; push(@a,$_)}; $n=@a;$s=sum(@a);$a=$s/@a;$m=max(@a);$mm=min(@a);$std=sqrt($sqsum/$n-($s/$n)*($s/$n));$mid=int @a/2;@srtd=sort @a;if(@a%2){$med=$srtd[$mid];}else{$med=($srtd[$mid-1]+$srtd[$mid])/2;};print "LAST_MONTH_COUNT=$n\nLAST_MONTH_SUM=$s\nLAST_MONTH_AVERAGE=$a\nLAST_MONTH_STD=$std\nLAST_MONTH_MEDIAN=$med\nLAST_MONTH_MAX=$m\nLAST_MONTH_MIN=$mm";'  > $TMPFILE
		# Now we "source" the script to set environment varaibles we use later
		. $TMPFILE
		rm $TMPFILE
		# Now we "clean up" the average and STD deviation
		LAST_MONTH_AVERAGE=`printf '%.2f' $LAST_MONTH_AVERAGE`
		LAST_MONTH_STD=`printf '%.2f' $LAST_MONTH_STD`
	else
		LAST_MONTH_COUNT="N/A"
		LAST_MONTH_SUM="N/A"
		LAST_MONTH_AVERAGE="N/A"
		LAST_MONTH_STD="N/A"
		LAST_MONTH_MEDIAN="N/A"
		LAST_MONTH_MAX="N/A"
		LAST_MONTH_MIN="N/A"
		LAST_MONTH_STD="N/A"
	fi

	#
	# THIS YEAR
	#
	# This was tested and works with 365 files :-)
	TMP=0
	for FILE in  `find $TMP_YEAR/ -name current-attack-count.data` ; do
		COUNT=`cat $FILE`
		(( TMP += $COUNT ))
	done
	THIS_YEAR=`expr $TMP + $TODAY`
	if [ $DEBUG  == 1 ] ; then echo "DEBUG this year statistics" ; fi
	# OK, this may not be 100% secure, but it's close enough for now
	TMPFILE=$(mktemp /tmp/output.XXXXXXXXXX)
	for FILE in  `find $TMP_YEAR/ -name current-attack-count.data` ; do cat $FILE; done |perl -e 'use List::Util qw(max min sum); @a=();while(<>){$sqsum+=$_*$_; push(@a,$_)}; $n=@a;$s=sum(@a);$a=$s/@a;$m=max(@a);$mm=min(@a);$std=sqrt($sqsum/$n-($s/$n)*($s/$n));$mid=int @a/2;@srtd=sort @a;if(@a%2){$med=$srtd[$mid];}else{$med=($srtd[$mid-1]+$srtd[$mid])/2;};print "YEAR_COUNT=$n\nYEAR_SUM=$s\nYEAR_AVERAGE=$a\nYEAR_STD=$std\nYEAR_MEDIAN=$med\nYEAR_MAX=$m\nYEAR_MIN=$mm";'  > $TMPFILE
	. $TMPFILE
	rm $TMPFILE
	YEAR_AVERAGE=`printf '%.2f' $YEAR_AVERAGE`
	YEAR_STD=`printf '%.2f' $YEAR_STD`


	#
	# EVERYTHING
	#
	# I have no idea where this breaks, but it's a big-ass number of files
	TMP=0
	for FILE in  `find . -name current-attack-count.data` ; do
		COUNT=`cat $FILE`
		(( TMP += $COUNT ))
	done
	TOTAL=`expr $TMP + $TODAY`
	# OK, this may not be 100% secure, but it's close enough for now
	if [ $DEBUG  == 1 ] ; then echo "DEBUG ALL  statistics" ; fi
	TMPFILE=$(mktemp /tmp/output.XXXXXXXXXX)
	for FILE in  `find . -name current-attack-count.data` ; do cat $FILE; done |perl -e 'use List::Util qw(max min sum); @a=();while(<>){$sqsum+=$_*$_; push(@a,$_)}; $n=@a;$s=sum(@a);$a=$s/@a;$m=max(@a);$mm=min(@a);$std=sqrt($sqsum/$n-($s/$n)*($s/$n));$mid=int @a/2;@srtd=sort @a;if(@a%2){$med=$srtd[$mid];}else{$med=($srtd[$mid-1]+$srtd[$mid])/2;};print "EVERYTHING_COUNT=$n\nEVERYTHING_SUM=$s\nEVERYTHING_AVERAGE=$a\nEVERYTHING_STD=$std\nEVERYTHING_MEDIAN=$med\nEVERYTHING_MAX=$m\nEVERYTHING_MIN=$mm";'  > $TMPFILE
	. $TMPFILE
	rm $TMPFILE
	EVERYTHING_AVERAGE=`printf '%.2f' $EVERYTHING_AVERAGE`
	EVERYTHING_STD=`printf '%.2f' $EVERYTHING_STD`

	#
	# Normalized data
	#
	if [ "x$HOSTNAME" == "x/" ] ;then
		# I have no idea where this breaks, but it's a big-ass number of files
		cd $HTML_DIR
		# OK, this may not be 100% secure, but it's close enough for now
		if [ $DEBUG  == 1 ] ; then echo "DEBUG ALL  statistics" ; fi
		TMPFILE=$(mktemp /tmp/output.XXXXXXXXXX)
#for FILE in  `find */historical -name current-attack-count.data ` ; do if [ ! -e $FILE.notfullday ] ; then echo $FILE; cat $FILE ; fi ; done >/tmp/ericw
#exit
		for FILE in  `find */historical -name current-attack-count.data ` ; do if [ ! -e $FILE.notfullday ] ; then cat $FILE ; fi ; done |perl -e 'use List::Util qw(max min sum); @a=();while(<>){$sqsum+=$_*$_; push(@a,$_)}; $n=@a;$s=sum(@a);$a=$s/@a;$m=max(@a);$mm=min(@a);$std=sqrt($sqsum/$n-($s/$n)*($s/$n));$mid=int @a/2;@srtd=sort @a;if(@a%2){$med=$srtd[$mid];}else{$med=($srtd[$mid-1]+$srtd[$mid])/2;};print "NORMALIZED_COUNT=$n\nNORMALIZED_SUM=$s\nNORMALIZED_AVERAGE=$a\nNORMALIZED_STD=$std\nNORMALIZED_MEDIAN=$med\nNORMALIZED_MAX=$m\nNORMALIZED_MIN=$mm";'  > $TMPFILE
		. $TMPFILE
cat $TMPFILE
		rm $TMPFILE
		NORMALIZED_AVERAGE=`printf '%.2f' $NORMALIZED_AVERAGE`
		NORMALIZED_STD=`printf '%.2f' $NORMALIZED_STD`
	else
		# I have no idea where this breaks, but it's a big-ass number of files
		cd $HTML_DIR
		# OK, this may not be 100% secure, but it's close enough for now
		if [ $DEBUG  == 1 ] ; then echo "DEBUG ALL  statistics" ; fi
		TMPFILE=$(mktemp /tmp/output.XXXXXXXXXX)
		for FILE in  `find ./historical -name current-attack-count.data ` ; do if [ ! -e $FILE.notfullday ] ; then cat $FILE ; fi ; done |perl -e 'use List::Util qw(max min sum); @a=();while(<>){$sqsum+=$_*$_; push(@a,$_)}; $n=@a;$s=sum(@a);$a=$s/@a;$m=max(@a);$mm=min(@a);$std=sqrt($sqsum/$n-($s/$n)*($s/$n));$mid=int @a/2;@srtd=sort @a;if(@a%2){$med=$srtd[$mid];}else{$med=($srtd[$mid-1]+$srtd[$mid])/2;};print "NORMALIZED_COUNT=$n\nNORMALIZED_SUM=$s\nNORMALIZED_AVERAGE=$a\nNORMALIZED_STD=$std\nNORMALIZED_MEDIAN=$med\nNORMALIZED_MAX=$m\nNORMALIZED_MIN=$mm";'  > $TMPFILE
		. $TMPFILE
cat $TMPFILE
		rm $TMPFILE
		NORMALIZED_AVERAGE=`printf '%.2f' $NORMALIZED_AVERAGE`
		NORMALIZED_STD=`printf '%.2f' $NORMALIZED_STD`

	fi
	
	sed -i "s/SSH Activity Today.*$/SSH Activity Today: $TODAY/" $1/index.shtml
	sed -i "s/SSH Activity This Month.*$/SSH Activity This Month: $THIS_MONTH/" $1/index.shtml
	sed -i "s/SSH Activity This Year.*$/SSH Activity This Year: $THIS_YEAR/" $1/index.shtml
	sed -i "s/SSH Activity Since Logging Started.*$/SSH Activity Since Logging Started: $TOTAL/" $1/index.shtml


	# Real Statistics here
	make_header "$1/statistics.shtml" "Assorted Statistics" "Analysis does not include today's numbers. Numbers rounded to two decimal places" "Time<BR>Frame" "Number<BR>of Days" "Total<BR>SSH attempts" "Average" "Std. Dev." "Median" "Max" "Min"
	echo "<TR><TD>So Far Today</TD><TD>1</TD><TD>$TODAY</TD><TD>N/A</TD><TD>N/A</TD><TD>N/A</TD><TD>N/A</TD><TD>N/A</TD></TR>" >>$1/statistics.shtml
	echo "<TR><TD>This Month</TD><TD> $MONTH_COUNT</TD><TD> $MONTH_SUM</TD><TD> $MONTH_AVERAGE</TD><TD> $MONTH_STD</TD><TD> $MONTH_MEDIAN</TD><TD> $MONTH_MAX</TD><TD> $MONTH_MIN" >>$1/statistics.shtml
	echo "<TR><TD>Last Month</TD><TD> $LAST_MONTH_COUNT</TD><TD> $LAST_MONTH_SUM</TD><TD> $LAST_MONTH_AVERAGE</TD><TD> $LAST_MONTH_STD</TD><TD> $LAST_MONTH_MEDIAN</TD><TD> $LAST_MONTH_MAX</TD><TD> $LAST_MONTH_MIN" >>$1/statistics.shtml
	echo "<TR><TD>This Year</TD><TD> $YEAR_COUNT</TD><TD> $YEAR_SUM</TD><TD> $YEAR_AVERAGE</TD><TD> $YEAR_STD</TD><TD> $YEAR_MEDIAN</TD><TD> $YEAR_MAX</TD><TD> $YEAR_MIN" >>$1/statistics.shtml
	echo "<TR><TD>Since Logging Started</TD><TD> $EVERYTHING_COUNT</TD><TD> $EVERYTHING_SUM</TD><TD> $EVERYTHING_AVERAGE</TD><TD> $EVERYTHING_STD</TD><TD> $EVERYTHING_MEDIAN</TD><TD> $EVERYTHING_MAX</TD><TD> $EVERYTHING_MIN" >>$1/statistics.shtml
	echo "<TR><TD>Normalized Since Logging Started</TD><TD> $NORMALIZED_COUNT</TD><TD> $NORMALIZED_SUM</TD><TD> $NORMALIZED_AVERAGE</TD><TD> $NORMALIZED_STD</TD><TD> $NORMALIZED_MEDIAN</TD><TD> $NORMALIZED_MAX</TD><TD> $NORMALIZED_MIN" >>$1/statistics.shtml
	echo "" >> $1/statistics.shtml
	echo "</TABLE><!--HEADERLINE -->" >> $1/statistics.shtml
	echo "<P>Normalized data is data that consists of only full days of attacks,<!--HEADERLINE --> " >> $1/statistics.shtml
	echo "AND to servers that are NOT protected by firewalls or other kinds of <!--HEADERLINE -->" >> $1/statistics.shtml
	echo "intrusion protection systems.<!--HEADERLINE -->"  >> $1/statistics.shtml
	make_footer "$1/statistics.shtml"

	sed -i "s/SSH Activity Today.*$/SSH Activity Today: $TODAY/" $1/index-long.shtml
	sed -i "s/SSH Activity This Month.*$/SSH Activity This Month: $THIS_MONTH/" $1/index-long.shtml
	sed -i "s/SSH Activity This Year.*$/SSH Activity This Year: $THIS_YEAR/" $1/index-long.shtml
	sed -i "s/SSH Activity Since Logging Started.*$/SSH Activity Since Logging Started: $TOTAL/" $1/index-long.shtml

	if [ "x$HOSTNAME" == "x/" ] ;then
		cd $HTML_DIR
		grep HEADERLINE statistics.shtml |egrep -v footer.html\|'</BODY'\|'</HTML'\|'</TABLE'\|'</TR' > statistics_all.shtml
		
		grep '<TR>' /var/www/html/honey/statistics.shtml |grep -v HEADERLINE |sed 's/<TD>/<TD>ALL Hosts /' >> statistics_all.shtml
		
		for FILE in */statistics.shtml  ; do
			NAME=`dirname $FILE`
			echo "<TR><TH colspan=8  ><A href=\"/honey/$NAME/\">$NAME</A></TH></TR>" >> statistics_all.shtml
			grep '<TR>' $FILE |sed "s/<TD>/<TD>$NAME /" >> statistics_all.shtml
		done
		
		echo "</TABLE>" >> statistics_all.shtml
		echo "" >> $$1/statistics.shtml
		echo "</TABLE><!--HEADERLINE -->" >> $$1/statistics.shtml
		echo "<P>Normalized data is data that consists of only full days of attacks,<!--HEADERLINE --> " >> $1/statistics.shtml
		echo "AND to servers that are NOT protected by firewalls or other kinds of <!--HEADERLINE -->" >> $1/statistics.shtml
		echo "intrusion protection systems.<!--HEADERLINE -->"  >> $1/statistics.shtml
		echo "<!--#include virtual=/honey/footer.html --> <!--HEADERLINE --> " >> statistics_all.shtml
		echo "</BODY><!--HEADERLINE -->" >> statistics_all.shtml
		echo "</HTML><!--HEADERLINE -->" >> statistics_all.shtml
	fi

	cd $ORIGINAL_DIRECTORY
}
	
############################################################################
# Current ssh attacks
#
# Called as ssh_attacks             $TMP_HTML_DIR $YEAR $PATH_TO_VAR_LOG DATE "messages*"
#
function ssh_attacks {
	local TMP_HTML_DIR=$1
	is_directory_good $TMP_HTML_DIR
	local YEAR=$2
	local PATH_TO_VAR_LOG=$3
	local DATE=$4
	local MESSAGES=$5
	local FILE_PREFIX=$6
	if [ $DEBUG  == 1 ] ; then echo "DEBUG TMP_HTML_DIR=$TMP_HTML_DIR, YEAR=$YEAR, PATH_TO_VARLOG=$PATH_TO_VAR_LOG, $DATE, MESSAGES=$MESSAGES, FILE_PREFIX=$FILE_PREFIX" ; fi

	#
	# I do a cd tp $PATH_TO_VAR_LOG to reduce the commandline length.  If the 
	# commandline is too long and breaks on your system due to there being 
	# way too many files in the directory, then you should probably be using
	# some other tool.
	local ORIGINAL_DIRECTORY=`pwd`
	cd $PATH_TO_VAR_LOG

	#
	# I hate making temporary files, but I have to so this doesn't take forever to run
	#
	# NOTE: Sometimes attackers use a malformed attack and don't specify
	# a username, so I am changing the Username field to NO-USERNAME-PROVIDED those attacks now
	# Example: 2015-02-26T12:46:40.500085-05:00 shepherd sshd-2222[28001]: IP: 107.150.35.218 Pass2222Log: Username:  Password: qwe123
	# So we grep out Username:\ \  so my reports work
	# It took 55 days for this bug to show up

	if [ $DEBUG  == 1 ] ; then echo -n "DEBUG-Making temp file now "  ;date; fi

	if [ "x$HOSTNAME" == "x/" ] ;then
		echo "hostname is not set"
		$SCRIPT_DIR/catall.sh $MESSAGES |grep ssh |grep "$DATE"|grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep | grep Password |sed 's/Username:\ \ /Username: NO-USERNAME-PROVIDED /'  > /tmp/LongTail-messages.$$
	else
		echo "hostname IS set to $HOSTNAME."
		$SCRIPT_DIR/catall.sh $MESSAGES |awk '$2 == "'$HOSTNAME'" {print}' |grep ssh |grep "$DATE"|grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep | grep Password |sed 's/Username:\ \ /Username: NO-USERNAME-PROVIDED /'  > /tmp/LongTail-messages.$$
	fi

	#-------------------------------------------------------------------------
	# Root
	if [ $DEBUG  == 1 ] ; then  echo -n "DEBUG-ssh_attack 1 " ; date; fi
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-root-passwords.shtml" "Root Passwords" " " "Count" "Password"

	cat /tmp/LongTail-messages.$$ |grep Username\:\ root |\
	awk -F'Username: ' '/Username/{print $2}' | awk '{print $3} ' |\
	sort |uniq -c|sort -nr |\
	awk '{printf("<TR><TD>%d</TD><TD><a href=\"https://www.google.com/search?q=&#34default+password+%s&#34\">%s</a> </TD></TR>\n",$1,$2,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-root-passwords.shtml

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-root-passwords.shtml" "Top 20 Root Passwords" "" "Count" "Password"
	grep -v HEADERLINE $TMP_HTML_DIR/$FILE_PREFIX-root-passwords.shtml | head -20   >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-root-passwords.shtml
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-root-passwords.shtml"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-root-passwords.shtml"
	cat $TMP_HTML_DIR/$FILE_PREFIX-top-20-root-passwords.shtml |grep -v HEADERLINE|sed -r 's/^<TR><TD>//' |sed 's/<.a> <.TD><.TR>//' |sed 's/<.TD><TD><a..*34">/ /' |grep -v ^$ > $TMP_HTML_DIR/$FILE_PREFIX-top-20-root-passwords.data



	#-------------------------------------------------------------------------
	# admin
	if [ $DEBUG  == 1 ] ; then echo -n "DEBUG-ssh_attack 2 "  ;date; fi
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-admin-passwords.shtml" "Admin Passwords" " " "Count" "Password"
	cat /tmp/LongTail-messages.$$ |grep Username\:\ admin |\
	awk -F'Username: ' '/Username/{print $2}' | awk '{print $3} ' |\
	sort |uniq -c|sort -nr |\
	awk '{printf("<TR><TD>%d</TD><TD><a href=\"https://www.google.com/search?q=&#34default+password+%s&#34\">%s</a> </TD></TR>\n",$1,$2,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-admin-passwords.shtml

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-admin-passwords.shtml" "Top 20 Admin Passwords" " " "Count" "Password"
	grep -v HEADERLINE $TMP_HTML_DIR/$FILE_PREFIX-admin-passwords.shtml | head -20   >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-admin-passwords.shtml
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-admin-passwords.shtml"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-admin-passwords.shtml"
	cat $TMP_HTML_DIR/$FILE_PREFIX-top-20-admin-passwords.shtml |grep -v HEADERLINE|sed -r 's/^<TR><TD>//' |sed 's/<.a> <.TD><.TR>//' |sed 's/<.TD><TD><a..*34">/ /' |grep -v ^$ > $TMP_HTML_DIR/$FILE_PREFIX-top-20-admin-passwords.data


	#-------------------------------------------------------------------------
	# Not root or admin PASSWORDS
	if [ $DEBUG  == 1 ] ; then echo -n "DEBUG-ssh_attack 3 "  ; date; fi
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-non-root-passwords.shtml" "Non Root Passwords" " " "Count" "Password"
	cat /tmp/LongTail-messages.$$ |egrep -v Username\:\ root\ \|Username\:\ admin\  |\
	awk -F'Username: ' '/Username/{print $2}' | awk '{print $3} '  |\
	sort |uniq -c|sort -nr |\
	awk '{printf("<TR><TD>%d</TD><TD><a href=\"https://www.google.com/search?q=&#34default+password+%s&#34\">%s</a> </TD></TR>\n",$1,$2,$2)}'  >> $TMP_HTML_DIR/$FILE_PREFIX-non-root-passwords.shtml

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-passwords.shtml" "Top 20 Non Root Passwords" " " "Count" "Password"
	#tail -20 $TMP_HTML_DIR/$FILE_PREFIX-non-root-passwords |grep -v HEADERLINE >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-passwords.shtml
	grep -v HEADERLINE $TMP_HTML_DIR/$FILE_PREFIX-non-root-passwords.shtml | head -20  >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-passwords.shtml
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-non-root-passwords.shtml"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-passwords.shtml"
	cat $TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-passwords.shtml |grep -v HEADERLINE|sed -r 's/^<TR><TD>//' |sed 's/<.a> <.TD><.TR>//' |sed 's/<.TD><TD><a..*34">/ /' |grep -v ^$ > $TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-passwords.data
	
	#-------------------------------------------------------------------------
	# Not root or admin ACCOUNTS
	if [ $DEBUG  == 1 ] ; then echo -n "DEBUG-ssh_attack 4 " ;date; fi
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-non-root-accounts.shtml" "Accounts Tried" " " "Count" "Account"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-accounts.shtml" "Top 20 Accounts Tried" "" "Count" "Account"
	cat /tmp/LongTail-messages.$$ |\
	awk -F'Username: ' '/Username/{print $2}' | awk '{print $1}'|\
	sort |uniq -c|sort -nr | awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-non-root-accounts.shtml
# NEED tac HERE
	grep -v HEADERLINE $TMP_HTML_DIR/$FILE_PREFIX-non-root-accounts.shtml | head -20   >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-accounts.shtml
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-non-root-accounts.shtml"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-accounts.shtml"
	cat $TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-accounts.shtml |grep -v HEADERLINE|sed -r 's/^<TR><TD>//' |sed 's/<.a> <.TD><.TR>//' |sed 's/<.TD><TD>/ /'|sed 's/<.TD><.TR>//' |grep -v ^$ > $TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-accounts.data
	
	#-------------------------------------------------------------------------
	# This works but gives only IP addresses
	if [ $DEBUG  == 1 ] ; then echo -n "DEBUG-ssh_attack 5 " ; date ; fi
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-ip-addresses.shtml" "IP Addresses" " " "Count" "IP Address" "WhoIS" "Blacklisted" "Attack Patterns"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-addresses.shtml" "Top 20 IP Addresses" " " "Count" "IP Address" "WhoIS" "Blacklisted" "Attack Patterns"
	# I need to make a temp file for this
	cat /tmp/LongTail-messages.$$  | grep IP: |grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | sed 's/^.*IP: //'|sed 's/ Pass..*$//' |sort |uniq -c |sort -nr |awk '{printf("<TR><TD>%d</TD><TD>%s</TD><TD><a href=\"http://whois.urih.com/record/%s\">Whois lookup</A></TD><TD><a href=\"http://www.dnsbl-check.info/?checkip=%s\">Blacklisted?</A></TD><TD><a href=\"/honey/attacks/ip_attacks.shtml#%s\">Attack Patterns</A></TD></TR>\n",$1,$2,$2,$2,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-ip-addresses.shtml

	grep -v HEADERLINE $TMP_HTML_DIR/$FILE_PREFIX-ip-addresses.shtml |head -20 |grep -v HEADERLINE >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-addresses.shtml
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-ip-addresses.shtml"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-addresses.shtml"
	
	#-------------------------------------------------------------------------
	# This translates IPs to countries
	if [ $DEBUG  == 1 ] ; then echo -n "DEBUG-ssh_attack 6, doing whois.pl lookups " ; date; fi
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-attacks-by-country.shtml" "Attacks by Country" " " "Count" "Country"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-attacks-by-country.shtml" "Top 20 Countries" " " "Count" "Country"
	# I need to make a temp file for this
	for IP in `cat /tmp/LongTail-messages.$$  |grep IP: | grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | sed 's/^.*IP: //'|sed 's/ Pass..*$//' |sort |uniq |grep -v \:\:1`; do   $SCRIPT_DIR/whois.pl $IP |grep -i country|head -1|sed 's/:/: /g' ; done | awk '{print $NF}' |sort |uniq -c |sort -n | awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-attacks-by-country.shtml
	sed -i -f $SCRIPT_DIR/translate_country_codes.sed  $TMP_HTML_DIR/$FILE_PREFIX-attacks-by-country.shtml
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-attacks-by-country.shtml |grep -v HEADERLINE >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-attacks-by-country.shtml
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-attacks-by-country.shtml"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-attacks-by-country.shtml"
	
	#-------------------------------------------------------------------------
	# Figuring out most common non-root pairs
	if [ $DEBUG  == 1 ] ; then echo -n "DEBUG-ssh_attack 7 Figuring out most common non-root pairs " ; date; fi
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-non-root-pairs.shtml" "Non Root Pairs" " " "Count" "Account:Password"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-pairs.shtml" "Top 20 Non Root Pairs" " " "Count" "Account:Password"

		cat /tmp/LongTail-messages.$$ |egrep -v Username\:\ root\ \|Username\:\ admin\  |\
		awk -F'Username: ' '/Username/{print $2}' | sed 's/ Password: /:/'|\
		sort |uniq -c|sort -nr | awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}'>> $TMP_HTML_DIR/$FILE_PREFIX-non-root-pairs.shtml

	if [ $FILE_PREFIX == "current" ] ;
	then
		cat /tmp/LongTail-messages.$$ |egrep -v Username\:\ root\ \|Username\:\ admin\  |\
		awk -F'Username: ' '/Username/{print $2}' | sed 's/ Password: /:/'|\
		sort |uniq -c|sort -nr | awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}'>> $TMP_HTML_DIR/$FILE_PREFIX-non-root-pairs.shtml

		cat /tmp/LongTail-messages.$$ |\
		awk -F'Username: ' '/Username/{print $2}' | sed 's/ Password: /:/' |gzip -c > $TMP_HTML_DIR/$FILE_PREFIX-account-password-pairs.data.gz
	else
		echo "DEBUG Non-current non-root-pairs"
		echo "DATE is $DATE"
		cat /tmp/LongTail-messages.$$ |egrep -v Username\:\ root\ \|Username\:\ admin\  |\
		awk -F'Username: ' '/Username/{print $2}' | sed 's/ Password: /:/'|\
		sort |uniq -c|sort -nr | awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}'>> $TMP_HTML_DIR/$FILE_PREFIX-non-root-pairs.shtml
		
	fi

	cat  $TMP_HTML_DIR/$FILE_PREFIX-non-root-pairs.shtml |grep -v HEADERLINE |head -20 >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-pairs.shtml

	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-non-root-pairs.shtml"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-pairs.shtml"

	#-------------------------------------------------------------------------
	# Figuring out ssh-attacks-by-time-of-day
	if [ $DEBUG  == 1 ] ; then echo -n "DEBUG-ssh_attack 7B Figuring out ssh-attacks-by-time-of-day " ; date; fi
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-ssh-attacks-by-time-of-day.shtml" "Historical SSH Attacks By Time Of Day" "" "Count" "Hour of Day"
	grep ssh /tmp/LongTail-messages.$$ | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep |grep Password | awk '{print $1}'| awk -FT '{print $2}' | awk -F: '{print $1}' |sort |uniq -c| awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-ssh-attacks-by-time-of-day.shtml
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-ssh-attacks-by-time-of-day.shtml"

	#-------------------------------------------------------------------------
	# raw data compressed 
	# This only prints the account and the password
	# This is different from the temp file I make earlier as it does
	# a grep for both Password AND password (Note the capitalization differences).
	if [ $DEBUG  == 1 ] ; then echo -n "DEBUG-ssh_attack 8, gathering data for raw-data.gz " ; date; fi
	if [ $FILE_PREFIX == "current" ] ;
	then
		# Lets make sure we have one for today and this month and this year
		# I added this code on 2015-03-17, Lets see if it breaks anything...
		TMP_YEAR=`date +%Y`
		TMP_MONTH=`date +%m`
		TMP_DAY=`date +%d`

		TMP_DIR="$TMP_HTML_DIR"
		if [ ! -d $TMP_DIR  ] ; then mkdir $TMP_DIR ; chmod a+rx $TMP_DIR; fi
		TMP_DIR="$TMP_HTML_DIR/historical"
		if [ ! -d $TMP_DIR  ] ; then mkdir $TMP_DIR ; chmod a+rx $TMP_DIR; fi
		TMP_DIR="$TMP_HTML_DIR/historical/$TMP_YEAR"
		if [ ! -d $TMP_DIR  ] ; then mkdir $TMP_DIR ; chmod a+rx $TMP_DIR; fi
		TMP_DIR="$TMP_HTML_DIR/historical/$TMP_YEAR/$TMP_MONTH"
		if [ ! -d $TMP_DIR  ] ; then mkdir $TMP_DIR ; chmod a+rx $TMP_DIR; fi
		TMP_DIR="$TMP_HTML_DIR/historical/$TMP_YEAR/$TMP_MONTH/$TMP_DAY"
		if [ ! -d $TMP_DIR  ] ; then mkdir $TMP_DIR ; chmod a+rx $TMP_DIR; fi

		if [ $OBFUSCATE_IP_ADDRESSES -gt 0 ] ; then
			cat /tmp/LongTail-messages.$$  |sed -r 's/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)[0-9]{1,3}/\1127/g'  |gzip -c > $TMP_HTML_DIR/$FILE_PREFIX-raw-data.gz
		else
			cat /tmp/LongTail-messages.$$ |gzip -c > $TMP_HTML_DIR/$FILE_PREFIX-raw-data.gz
		fi
		cp $TMP_HTML_DIR/$FILE_PREFIX-raw-data.gz $TMP_HTML_DIR/historical/$TMP_YEAR/$TMP_MONTH/$TMP_DAY/current-raw-data.gz
		chmod a+r $TMP_HTML_DIR/historical/$TMP_YEAR/$TMP_MONTH/$TMP_DAY/current-raw-data.gz
	fi


	if [ $DEBUG ] ; then echo -n "Wrote to $TMP_HTML_DIR/$FILE_PREFIX-raw-data.gz "; date ;fi
	#
	# I only need the count data for today, so there's no point counting 7, 30, or historical
	#
	if [ $FILE_PREFIX == "current" ] ;
	then
		TODAY=`$SCRIPT_DIR/catall.sh $TMP_HTML_DIR/$FILE_PREFIX-raw-data.gz  |grep ssh | grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |egrep Password|wc -l`
		echo $TODAY > $TMP_HTML_DIR/$FILE_PREFIX-attack-count.data
	fi

	#
	# read and run any LOCALLY WRITTEN reports
	#
	if [ $DEBUG ] ; then echo "Running ssh-local-reports"; fi
	. $SCRIPT_DIR/Longtail-ssh-local-reports

	# cd back to the original directory.  this should be the last command in 
	# the function.
	cd $ORIGINAL_DIRECTORY
	rm /tmp/LongTail-messages.$$
	if [ $DEBUG  == 1 ] ; then echo -n "DEBUG-Done with ssh_attack " ; date; fi
}

#########################################################################################################
# HTTP STUFF HERE
# http_attacks $TMP_HTML_DIR $YEAR $PATH_TO_VAR_LOG_HTTPD "$DATE"  "access_log"  "current"
#
function http_attacks {
	if [ $DEBUG  == 1 ] ; then echo "DEBUG-Starting http_attacks now" ; fi
	TMP_HTML_DIR=$1
	is_directory_good $TMP_HTML_DIR
	YEAR=$2
	PATH_TO_VAR_LOG_HTTPD=$3
	DATE=$4
	ACCESS_LOG=$5
	FILE_PREFIX=$6
	
	#	Date format should be like this --> DATE=`date +%d/%b/%Y`
	#
	# I do a cd tp $PATH_TO_VAR_LOG to reduce the commandline length.  If the 
	# commandline is too long and breaks on your system due to there being 
	# way too many files in the directory, then you should probably be using
	# some other tool.
	ORIGINAL_DIRECTORY=`pwd`
	cd $PATH_TO_VAR_LOG_HTTPD

	
	#####################################################################################################
	# Access logs here
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-access-log" "Webpages" ""  
	echo "</TABLE><!--HEADERLINE -->" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log
	echo "<PRE><!--HEADERLINE -->" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log
	$SCRIPT_DIR/catall.sh $ACCESS_LOG | grep -hvf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep|grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep |grep $DATE  >> $TMP_HTML_DIR/$FILE_PREFIX-access-log
	echo "</PRE><!--HEADERLINE -->" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-access-log"
	
	
	#####################################################################################################
	#echo "What webpages are they looking for?"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-shellshock-webpages" "Shellshock Requests"  "" "Count" "Webpage"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-shellshock-webpages" "Top 20 Shellshock Requests"  "" "Count" "Webpage"
	$SCRIPT_DIR/catall.sh $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \:\; |sed 's/^..*\"GET\ //'| sed 's/^..*\"HEAD\ //' |sed 's/ ..*$//'|sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-shellshock-webpages
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-shellshock-webpages |grep -v HEADERLINE >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-shellshock-webpages
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-shellshock-webpages"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-shellshock-webpages"

	
	#####################################################################################################
	#echo "What are the actual attacks they are trying to run?"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-attacks" "Attacks"   "" "Count" "Attack"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-attacks" "Top 20 Attacks"   "" "Count" "Attack"
	$SCRIPT_DIR/catall.sh $ACCESS_LOG  |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \:\; |sed 's/^..*\"GET\ //'| sed 's/^..*\"HEAD\ //' | sed 's/^..*:;//' |sed 's/\}\;//'|sort |uniq -c|sort -n  | sed -r 's/^ +/<TR><TD>/'|sed 's/ /<\/TD><TD>/'|sed 's/$/<\/TD><\/TR>/' >> $TMP_HTML_DIR/$FILE_PREFIX-attacks
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-attacks  |grep -v HEADERLINE>> $TMP_HTML_DIR/$FILE_PREFIX-top-20-attacks
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-attacks"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-attacks"
	
	#####################################################################################################
	#echo "Where are they getting their payloads from or trying to connect to with bash?"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-payloads" "Payloads"   "" "Count" "Attack"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-payloads" "Top 20 Payloads"   "" "Count" "Attack"
	$SCRIPT_DIR/catall.sh $ACCESS_LOG  |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \:\; |sed 's/^..*\"GET\ //'| sed 's/^..*\"HEAD\ //' | sed 's/^..*:;//' |sed 's/\}\;//' |sed 's/^..*http/http/'|sed 's/^..*ftp/ftp/' |sed 's/;..*//'| sed 's/^..*\/dev\/tcp/\/dev\/tcp/' |sed 's/0>.*//' |sed 's/>.*//' |sort |uniq -c |sort -n  |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-payloads
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-payloads  |grep -v HEADERLINE>> $TMP_HTML_DIR/$FILE_PREFIX-top-20-payloads
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-payloads"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-payloads"
	
	#####################################################################################################
	#echo "What are they trying to rm?"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-rm-attempts" "rm Attempts"   "" "Count" "Attack"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-rm-attempts" "Top 20 rm Attempts"   "" "Count" "Attack"
	grep -h \:\; $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep perl|sed 's/..*perl/perl/'|sed 's/^..*rm/rm/' |sort |uniq -c|sort -n |grep rm |sed 's/;.*//' |sort -n |sed 's/^/<TR><TD>/'|sed 's/$/<\/TD><\/TR>/'|sed 's/ rm/<\/TD><TD>rm/' >> $TMP_HTML_DIR/$FILE_PREFIX-rm-attempts
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-rm-attempts  |grep -v HEADERLINE>> $TMP_HTML_DIR/$FILE_PREFIX-top-20-rm-attempts
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-rm-attempts"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-rm-attempts"
	
	#####################################################################################################
	#echo "Shellshock attacks not explitly using perl"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-shellshock-not-using-perl" "shellshock-not-using-perl"   "" "Count" "Attack"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-shellshock-not-using-perl" "Top 20 shellshock-not-using-perl"   "" "Count" "Attack"
	grep -h \:\; $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep  -v perl |sed 's/^..*\"GET\ //'| sed 's/^..*\"HEAD\ //' | sed 's/^..*:;//' |sed 's/\}\;//' |sort |uniq -c |sort -n |sed 's/^ *//' |sed 's/^/<TR><TD>/' |sed 's/$/<\/TD><\/TR>/' |sed 's/ /<\/TD><TD>/'   >> $TMP_HTML_DIR/$FILE_PREFIX-shellshock-not-using-perl

	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-shellshock-not-using-perl  |grep -v HEADERLINE>> $TMP_HTML_DIR/$FILE_PREFIX-top-20-shellshock-not-using-perl
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-shellshock-not-using-perl"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-shellshock-not-using-perl"
	
	#####################################################################################################
	# Shellshock here
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-access-log-shell-shock" "access-log-shell-shock" ""  
	echo "</TABLE><PRE>" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log-shell-shock
	grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep |grep $DATE |grep \:\; >> $TMP_HTML_DIR/$FILE_PREFIX-access-log-shell-shock
	echo "</PRE>" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log-shell-shock
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-access-log-shell-shock"

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-shell-shock" "ip-access-log-shell-shock"   "" "Count" "Attack"
	grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -v $SCRIPT_DIR/LongTail-exclude-webpages.grep |grep $DATE |grep \:\; | awk '{print $1}' |sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}'>> $TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-shell-shock
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-shell-shock"

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-country-access-log-shell-shock" "country-access-log-shell-shock"   "" "Count" "Country"
	for IP in `grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \:\; | awk '{print $1}' |sort |uniq` ;do $SCRIPT_DIR/whois.pl $IP |grep -i country|head -1|sed 's/:/: /g' ; done | awk '{print $NF}' |sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-country-access-log-shell-shock
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-country-access-log-shell-shock"
	sed -i -f $SCRIPT_DIR/translate_country_codes.sed.orig  $TMP_HTML_DIR/$FILE_PREFIX-country-access-log-shell-shock
	
	#####################################################################################################
	# 404 probes here
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-access-log-404" "access-log-404"  ""  
	echo "</TABLE><PRE>" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log-404
	grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -v \:\; |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \ 404\  >> $TMP_HTML_DIR/$FILE_PREFIX-access-log-404
	echo "</PRE>" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log-404
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-access-log-404"

#-------------------------------------------------------------------------
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-open-proxy-log-404" "open-proxy-log-404"  ""  
	echo "</TABLE><PRE>" >> $TMP_HTML_DIR/$FILE_PREFIX-open-proxy-log-404
	grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -v \:\; |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \ 404\ |grep 'GET http:' >> $TMP_HTML_DIR/$FILE_PREFIX-open-proxy-log-404
	echo "</PRE>" >> $TMP_HTML_DIR/$FILE_PREFIX-open-proxy-log-404
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-open-proxy-log-404"

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-ip-open-proxy-404" "ip-open-proxy-404"   "" "Count" "IP Address"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-open-proxy-404" "Top 20 ip-open-proxy-404"   "" "Count" "IP Address"
	grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -v \:\; |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \ 404\ |grep 'GET http:' | awk '{print $1}' |sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-ip-open-proxy-404
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-ip-open-proxy-404  |grep -v HEADERLINE>> $TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-open-proxy-404
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-ip-open-proxy-404"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-open-proxy-404"

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-country-open-proxy-log-404" "country-open-proxy-log-404"   "" "Count" "Country"
	for IP in `grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep |grep -v \:\; |grep $DATE |grep \ 404\ |grep 'GET http:'  | awk '{print $1}' |sort |uniq` ;do $SCRIPT_DIR/whois.pl $IP |grep -i country|head -1|sed 's/:/: /g' ; done | awk '{print $NF}' |sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-country-open-proxy-log-404
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-country-open-proxy-log-404"
	sed -i -f $SCRIPT_DIR/translate_country_codes.sed.orig  $TMP_HTML_DIR/$FILE_PREFIX-country-open-proxy-log-404

#-------------------------------------------------------------------------

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-404" "ip-access-log-404"   "" "Count" "IP Address"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-access-log-404" "Top 20 ip-access-log-404"   "" "Count" "IP Address"

	grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -v \:\; |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep |grep $DATE |grep \ 404\  | awk '{print $1}' |sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-404
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-404  |grep -v HEADERLINE>> $TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-access-log-404
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-404"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-access-log-404"

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-country-access-log-404" "country-access-log-404"   "" "Count" "Country"
	for IP in `grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep |grep -v \:\; |grep $DATE |grep \ 404\  | awk '{print $1}' |sort |uniq` ;do $SCRIPT_DIR/whois.pl $IP |grep -i country|head -1|sed 's/:/: /g' ; done | awk '{print $NF}' |sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-country-access-log-404
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-country-access-log-404"
	sed -i -f $SCRIPT_DIR/translate_country_codes.sed.orig  $TMP_HTML_DIR/$FILE_PREFIX-country-access-log-404


	make_header "$TMP_HTML_DIR/$FILE_PREFIX-shellshock-by-time-of-day" "shellshock-by-time-of-day"   "" "Count" "Time"
	$SCRIPT_DIR/catall.sh $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  |grep -v \/honey\/ | grep \:\; |awk -F: '{print $2}' |sort|uniq -c |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-shellshock-by-time-of-day
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-shellshock-by-time-of-day"

	#
	# read and run any LOCALLY WRITTEN reports
	#
	. $SCRIPT_DIR/Longtail-httpd-local-reports


	# cd back to the original directory.  this should be the last command in 
	# the function.
	cd $ORIGINAL_DIRECTORY

}

#
############################################################################
#

function do_ssh {
	if [ $DEBUG  == 1 ] ; then echo "DEBUG-in do_ssh now" ; fi
	#-----------------------------------------------------------------
	# Lets count the ssh attacks
	count_ssh_attacks $HTML_DIR $PATH_TO_VAR_LOG "messages*"
	
	#----------------------------------------------------------------
	# Lets check the ssh logs
	ssh_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG "$DATE"  "messages" "current"
	
	#----------------------------------------------------------------
	# Lets check the ssh logs for the last 7 days
	LAST_WEEK=""
	for i in 1 2 3 4 5 6 7 ; do
		TMP_DATE=`date "+%Y/%m/%d" --date="$i day ago"`
		if [ "$LAST_WEEK" == "" ] ; then
			LAST_WEEK="$HTML_DIR/historical/$TMP_DATE/current-raw-data.gz"
		else
			LAST_WEEK="$LAST_WEEK $HTML_DIR/historical/$TMP_DATE/current-raw-data.gz"
		fi
	done
	TMP_PATH_TO_VAR_LOG=$PATH_TO_VAR_LOG
	ssh_attacks $HTML_DIR $YEAR "/" "."      "$LAST_WEEK" "last-7-days"
	PATH_TO_VAR_LOG=$TMP_PATH_TO_VAR_LOG

	#----------------------------------------------------------------
	# Lets check the ssh logs for the last 30 days
	LAST_MONTH=""
	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
		TMP_DATE=`date "+%Y/%m/%d" --date="$i day ago"`
		if [ "$LAST_MONTH" == "" ] ; then
			LAST_MONTH="$HTML_DIR/historical/$TMP_DATE/current-raw-data.gz"
		else
			LAST_MONTH="$LAST_MONTH $HTML_DIR/historical/$TMP_DATE/current-raw-data.gz"
		fi
	done
	TMP_PATH_TO_VAR_LOG=$PATH_TO_VAR_LOG
	ssh_attacks $HTML_DIR $YEAR "/" "."      "$LAST_MONTH" "last-30-days"
	PATH_TO_VAR_LOG=$TMP_PATH_TO_VAR_LOG


	if [ $DEBUG  == 1 ] ; then echo "DEBUG-doing historical now" ; fi
	TMP_PATH_TO_VAR_LOG=$PATH_TO_VAR_LOG
	ssh_attacks $HTML_DIR $YEAR "/$HTML_DIR/historical/" "."      "*/*/*/current-raw-data.gz" "historical"
	PATH_TO_VAR_LOG=$TMP_PATH_TO_VAR_LOG
	
	# This is an example of how to call ssh_attacks for past dates and 
	# put the reports in the $HTML_DIR/historical/Year/month/date directory
	# Make sure you edit the date in BOTH places in the line.
	#
#	for LOOP in 04 05 06 07 08 09 ; do
#		mkdir -p $HTML_DIR/historical/2015/01/$LOOP
#		ssh_attacks $HTML_DIR/historical/2015/01/$LOOP $YEAR $PATH_TO_VAR_LOG "2015-01-$LOOP"      "messages*" "current"
#	done
#	for LOOP in 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31; do
#		mkdir -p $HTML_DIR/historical/2015/01/$LOOP
#		ssh_attacks $HTML_DIR/historical/2015/01/$LOOP $YEAR $PATH_TO_VAR_LOG "2015-01-$LOOP"      "messages*" "current"
#	done
#	for LOOP in 01 02 03 04 05 06 07 08 09 ; do
#		mkdir -p $HTML_DIR/historical/2015/02/$LOOP
#		ssh_attacks $HTML_DIR/historical/2015/02/$LOOP $YEAR $PATH_TO_VAR_LOG "2015-02-$LOOP"      "messages*" "current"
#	done
#	for LOOP in 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28; do
#	for LOOP in 25 26 27 28; do
#		mkdir -p $HTML_DIR/historical/2015/02/$LOOP
#		ssh_attacks $HTML_DIR/historical/2015/02/$LOOP $YEAR $PATH_TO_VAR_LOG "2015-02-$LOOP"      "messages*" "current"
#	done
#	for LOOP in 01 02 03 04 05 06 07 08 09 ; do
#		mkdir -p $HTML_DIR/historical/2015/03/$LOOP
#		ssh_attacks $HTML_DIR/historical/2015/03/$LOOP $YEAR $PATH_TO_VAR_LOG "2015-03-$LOOP"      "messages*" "current"
#	done
#	for LOOP in 10 11 12 13 ; do
#		mkdir -p $HTML_DIR/historical/2015/03/$LOOP
#		ssh_attacks $HTML_DIR/historical/2015/03/$LOOP $YEAR $PATH_TO_VAR_LOG "2015-03-$LOOP"      "messages*" "current"
#	done

# Example of getting a single date.  Make sure you edit the date in BOTH places in the line.
#	ssh_attacks $HTML_DIR/historical/2015/02/24 $YEAR $PATH_TO_VAR_LOG "2015-02-24"      "messages*" "current"
#	ssh_attacks $HTML_DIR/historical/2015/02/25 $YEAR $PATH_TO_VAR_LOG "2015-02-25"      "messages*" "current"
#	ssh_attacks $HTML_DIR/historical/2015/02/26 $YEAR $PATH_TO_VAR_LOG "2015-02-26"      "messages*" "current"
#	ssh_attacks $HTML_DIR/historical/2015/03/14 $YEAR $PATH_TO_VAR_LOG "2015-03-14"      "messages*" "current"
	
	
	#-----------------------------------------------------------------
	# Now lets do some long term ssh reports....  Lets do a comparison of 
	# top 20 non-root-passwords and top 20 root passwords
	#-----------------------------------------------------------------
	cd $HTML_DIR/historical 
	make_header "$HTML_DIR/trends-in-non-root-passwords.shtml" "Trends In Non Root Passwords From Most Common To 20th"  "Format is number of tries : password tried.  Entries In red are the first time that entry was seen." "Date" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20"
	
	TMPFILE=$(mktemp /tmp/output.XXXXXXXXXX)
	if [ $DEBUG  == 1 ] ; then echo "DEBUG-doing trends-in-non-root-passwords" ; fi
	for FILE in `find . -name 'current-top-20-non-root-passwords.shtml'|sort -nr ` ; do  echo "<TR>";echo -n "<TD>"; \
		echo -n "$FILE $FILE"  |\
		sed 's/current-top-20-non-root-passwords.shtml//g' |\
		sed 's/\.\///g' |\
		sed 's/^/<A HREF=\"historical\//' |\
		sed 's/\/ /\/\">/' |\
		sed 's/$/ <\/a>/' ; \
		echo "</TD>"; grep TR $FILE |\
		grep -v HEADERLINE | \
		sed 's/<TR><TD>/<TD>/' |sed 's/<.TD><TD>/:/' |sed 's/<.TR>//'; echo "</TR>" ; done >> $TMPFILE

	#
	# code to color code NEW entries
	#
	tac $TMPFILE  |\
	perl -e ' while (<>){
	if (/<A HREF="historical/){print; next;}
	if (/^<TD/){
		$line=$_;
		$tmp_line=$_;
		$tmp_line =~ s/^..*">//;
		$tmp_line =~ s/<\/a>.*$//;
		
		if (defined $password{"$tmp_line"}){
			print $line;
		}
		else {
			$line =~ s/<TD/<TD bgcolor=#FF0000/;
			$password{"$tmp_line"}=1;
			print $line;
		}
	}
	else {
		print;
	}
	}' |tac >> $HTML_DIR/trends-in-non-root-passwords.shtml
	rm $TMPFILE

	make_footer "$HTML_DIR/trends-in-non-root-passwords.shtml"
	sed -i 's/<TD>/<TD class="td-some-name">/g' $HTML_DIR/trends-in-non-root-passwords.shtml
	

	#-----------------------------------------------------------------
	cd $HTML_DIR/historical 
	if [ $DEBUG  == 1 ] ; then echo "DEBUG-doing trends-in-root-passwords" ; fi
	make_header "$HTML_DIR/trends-in-root-passwords.shtml" "Trends In Root Passwords From Most Common To 20th"  "Format is number of tries : password tried.  Entries In red are the first time that entry was seen." "Date" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20"

	TMPFILE=$(mktemp /tmp/output.XXXXXXXXXX)
	for FILE in `find . -name 'current-top-20-root-passwords.shtml'|sort -nr ` ; do  echo "<TR>";echo -n "<TD>"; \
		echo -n "$FILE $FILE" |\
		sed 's/current-top-20-root-passwords.shtml//g'|\
		sed 's/\.\///g' |\
		sed 's/^/<A HREF=\"historical\//' |\
		sed 's/\/ /\/\">/' |\
		sed 's/$/ <\/a>/' ; \
		echo "</TD>"; grep TR $FILE |\
		grep -v HEADERLINE   |\
		sed 's/<TR><TD>/<TD>/' |sed 's/<.TD><TD>/:/' |sed 's/<.TR>//'; echo "</TR>" ; done >> $TMPFILE

	#
	# code to color code NEW entries
	#
	tac $TMPFILE  |\
	perl -e ' while (<>){
	if (/<A HREF="historical/){print; next;}
	if (/^<TD/){
		$line=$_;
		$tmp_line=$_;
		$tmp_line =~ s/^..*">//;
		$tmp_line =~ s/<\/a>.*$//;
		
		if (defined $password{"$tmp_line"}){
			print $line;
		}
		else {
			$line =~ s/<TD/<TD bgcolor=#FF0000/;
			$password{"$tmp_line"}=1;
			print $line;
		}
	}
	else {
		print;
	}
	}' |tac >> $HTML_DIR/trends-in-root-passwords.shtml
	rm $TMPFILE
	
	make_footer "$HTML_DIR/trends-in-root-passwords.shtml"
	sed -i 's/<TD>/<TD class="td-some-name">/g' $HTML_DIR/trends-in-root-passwords.shtml
	cd $HTML_DIR/historical 
	
	#-----------------------------------------------------------------
	cd $HTML_DIR/historical 
	if [ $DEBUG  == 1 ] ; then echo "DEBUG-doing trends-in-admin-passwords" ; fi

	make_header "$HTML_DIR/trends-in-admin-passwords.shtml" "Trends In Admin Passwords From Most Common To 20th"  "Format is number of tries : password tried.  Entries In red are the first time that entry was seen." "Date" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20"
	
	TMPFILE=$(mktemp /tmp/output.XXXXXXXXXX)
	for FILE in `find . -name 'current-top-20-admin-passwords.shtml'|sort -nr ` ; do  echo "<TR>";echo -n "<TD>"; \
		echo -n "$FILE $FILE" |\
		sed 's/current-top-20-admin-passwords.shtml//g'|\
		sed 's/\.\///g' |\
		sed 's/^/<A HREF=\"historical\//' |\
		sed 's/\/ /\/\">/' |\
		sed 's/$/ <\/a>/' ; \
		echo "</TD>"; grep TR $FILE |\
		grep -v HEADERLINE   |\
		sed 's/<TR><TD>/<TD>/' |sed 's/<.TD><TD>/:/' |sed 's/<.TR>//'; echo "</TR>" ; done  >> $TMPFILE

	#
	# code to color code NEW entries
	#
	tac $TMPFILE  |\
	perl -e ' while (<>){
	if (/<A HREF="historical/){print; next;}
	if (/^<TD/){
		$line=$_;
		$tmp_line=$_;
		$tmp_line =~ s/^..*">//;
		$tmp_line =~ s/<\/a>.*$//;
		
		if (defined $password{"$tmp_line"}){
			print $line;
		}
		else {
			$line =~ s/<TD/<TD bgcolor=#FF0000/;
			$password{"$tmp_line"}=1;
			print $line;
		}
	}
	else {
		print;
	}
	}' |tac >> $HTML_DIR/trends-in-admin-passwords.shtml
	rm $TMPFILE
	
	make_footer "$HTML_DIR/trends-in-admin-passwords.shtml"
	sed -i 's/<TD>/<TD class="td-some-name">/g' $HTML_DIR/trends-in-admin-passwords.shtml
	cd $HTML_DIR/historical 

	#-----------------------------------------------------------------
	cd $HTML_DIR/historical 
	if [ $DEBUG  == 1 ] ; then echo "DEBUG-doing trends-in-Accounts" ; fi

	make_header "$HTML_DIR/trends-in-accounts.shtml" "Trends In Accounts Tried From Most Common To 20th"  "Format is number of tries : password tried.  Entries In red are the first time that entry was seen." "Date" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20"
	
	TMPFILE=$(mktemp /tmp/output.XXXXXXXXXX)
	for FILE in `find . -name 'current-top-20-non-root-accounts.shtml'|sort -nr ` ; do  echo "<TR>";echo -n "<TD>"; \
		echo -n "$FILE $FILE" |\
		sed 's/current-top-20-non-root-accounts.shtml//g'|\
		sed 's/\.\///g' |\
		sed 's/^/<A HREF=\"historical\//' |\
		sed 's/\/ /\/\">/' |\
		sed 's/$/ <\/a>/' ; \
		echo "</TD>"; grep TR $FILE |\
		grep -v HEADERLINE   |\
		sed 's/<TR><TD>/<TD>/' |sed 's/<.TD><TD>/:/' |sed 's/<.TR>//'; echo "</TR>" ; done  >> $TMPFILE

	#
	# code to color code NEW entries
	#
	tac $TMPFILE  |\
	perl -e ' while (<>){
	if (/<A HREF="historical/){print; next;}
	if (/^<TD/){
		$line=$_;
		$tmp_line=$_;
		$tmp_line =~ s/^..*">//;
		$tmp_line =~ s/<\/a>.*$//;
		$tmp_line=~ s/^.*://;
		$tmp_line=~ s/<.*$//;

		
		if (defined $password{"$tmp_line"}){
			print $line;
		}
		else {
			$line =~ s/<TD/<TD bgcolor=#FF0000/;
			$password{"$tmp_line"}=1;
			print $line;
		}
	}
	else {
		print;
	}
	}' |tac >> $HTML_DIR/trends-in-accounts.shtml
	rm $TMPFILE
	
	make_footer "$HTML_DIR/trends-in-accounts.shtml"
	sed -i 's/<TD>/<TD class="td-some-name">/g' $HTML_DIR/trends-in-accounts.shtml
	cd $HTML_DIR/historical 

	#-----------------------------------------------------------------
	cd $HTML_DIR/
	if [ $DEBUG  == 1 ] ; then echo "DEBUG-Making Graphics now" ; fi
	if [ $GRAPHS == 1 ] ; then
		for FILE in *.data ; do 
			if [ ! "$FILE" == "current-attack-count.data" ] ; then
				GRAPHIC_FILE=`echo $FILE | sed 's/.data/.png/'`
				TITLE=`echo $FILE | sed 's/non-root-passwords/non-root-non-admin-passwords/' | sed 's/-/ /g' |sed 's/.data//'`
				if [ -s "$FILE" ] ; then
					if [[ $FILE == *"accounts"* ]] ; then
						php /usr/local/etc/LongTail_make_graph.php $FILE "$TITLE" "Accounts" "Number of Tries"> $GRAPHIC_FILE
					fi
					if [[ $FILE == *"password"* ]] ; then
						php /usr/local/etc/LongTail_make_graph.php $FILE "$TITLE" "Passwords" "Number of Tries"> $GRAPHIC_FILE
					fi
				else #We have an empty file, deal with it here
					echo "0 0" >/tmp/LongTail.data.$$
					if [[ $FILE == *"accounts"* ]] ; then
						php /usr/local/etc/LongTail_make_graph.php /tmp/LongTail.data.$$ "Not Enough Data Today For $TITLE" "Accounts" "Number of Tries"> $GRAPHIC_FILE
					fi
					if [[ $FILE == *"password"* ]] ; then
						php /usr/local/etc/LongTail_make_graph.php /tmp/LongTail.data.$$ "Not Enough Data Today For $TITLE" "Passwords" "Number of Tries"> $GRAPHIC_FILE
					fi
					rm /tmp/LongTail.data.$$
				fi
			fi
		done        
	fi    
}

function make_daily_attacks_chart {
	cd $HTML_DIR
	cd historical
	
	make_header "$HTML_DIR/attacks_by_day.shtml" "Attacks By Day"  "" 

#for year in * ; do
##echo "$year" >> $HTML_DIR/attacks_by_day.shtml
#if [ -d $year ] ; then
#cd $year
#for month in 01 02 03 04 05 06 07 08 09 10 11 12 ; do
#if [ -d "$month" ] ; then
#echo "<TR><TD>$year</TD><TD>$month</TD>" >> $HTML_DIR/attacks_by_day.shtml
#cd  $month
#for day in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31; do
#if [ -e $day/current-attack-count.data ] ; then
#count=`cat $day/current-attack-count.data`
#echo -n "<TD>$count</TD>" >> $HTML_DIR/attacks_by_day.shtml
#else
#echo -n "<TD>N/A</TD>" >> $HTML_DIR/attacks_by_day.shtml
#fi
#done
#echo "</TR>" >> $HTML_DIR/attacks_by_day.shtml
#cd ..
#fi
#done
#cd ..
#fi
#done
	$SCRIPT_DIR/LongTail_make_daily_attacks_chart.pl "$HTML_DIR/historical" >> $HTML_DIR/attacks_by_day.shtml 

	make_footer "$HTML_DIR/attacks_by_day.shtml"

}

function do_httpd {
	#-----------------------------------------------------------------
	# Lets check the httpd access_logs logs
	# Reset the date to an access_log format
	DATE=`date +%d/%b/%Y`
	#DATE=`date +%Y-%m-%e`
	if [ $DEBUG  == 1 ] ; then echo "DEBUG-in do_httpd now" ; fi
	if [ $DEBUG  == 1 ] ; then echo "DEBUG-YEAR is $YEAR, PATH_TO_VAR_LOG_HTTPD is $PATH_TO_VAR_LOG_HTTPD " ; fi
	
	http_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG_HTTPD "$DATE"  "access_log"  "current"
	http_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG_HTTPD "."      "access_log*" "historical"
	
	LAST_WEEK=""
	for i in 1 2 3 4 5 6 7 ; do
	  TMP_DATE=`date +"%d/%b/%Y" --date="$i day ago"`
	  #TMP_DATE=`date +"%Y-%m-%e" --date="$i day ago"`
	  if [ "$LAST_WEEK" == "" ] ; then
	    LAST_WEEK="$TMP_DATE"
	  else
	    LAST_WEEK="$LAST_WEEK\\|$TMP_DATE"
	  fi
	done
	
	http_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG_HTTPD "$LAST_WEEK"      "access_log*" "last-7-days"
	
	
	LAST_MONTH=""
	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
	  TMP_DATE=`date +"%d/%b/%Y" --date="$i day ago"`
	  #TMP_DATE=`date +"%Y-%m-%e" --date="$i day ago"`
	  if [ "$LAST_MONTH" == "" ] ; then
	    LAST_MONTH="$TMP_DATE"
	  else
	    LAST_MONTH="$LAST_MONTH\\|$TMP_DATE"
	  fi
	done
	
	http_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG_HTTPD "$LAST_MONTH"      "access_log*" "last-30-days"
}

############################################################################
# Set permissions so everybody can read the files
#
function set_permissions {
	TMP_HTML_DIR=$1
	chmod a+r $TMP_HTML_DIR/*
}

############################################################################
# Create historical copies of the data
#
# This creates yesterdays data, once "yesterday" is over
#
function create_historical_copies {
	TMP_HTML_DIR=$1

	if [ $HOUR -eq 0 ]; then
		YESTERDAY_YEAR=`date  +"%Y" --date="1 day ago"`
		YESTERDAY_MONTH=`date  +"%m" --date="1 day ago"`
		YESTERDAY_DAY=`date  +"%e" --date="1 day ago"`

		cd  $TMP_HTML_DIR

		mkdir -p $TMP_HTML_DIR/historical/$YESTERDAY_YEAR/$YESTERDAY_MONTH/$YESTERDAY_DAY
		cp $TMP_HTML_DIR/index-historical.shtml $TMP_HTML_DIR/historical/$YESTERDAY_YEAR/$YESTERDAY_MONTH/$YESTERDAY_DAY/index.shtml
		# I do individual chmods so I don't do chmod's of thousands of files...
		chmod a+rx $TMP_HTML_DIR/historical
		chmod a+rx $TMP_HTML_DIR/historical/$YESTERDAY_YEAR
		chmod a+rx $TMP_HTML_DIR/historical/$YESTERDAY_YEAR/$YESTERDAY_MONTH
		chmod a+rx $TMP_HTML_DIR/historical/$YESTERDAY_YEAR/$YESTERDAY_MONTH/$YESTERDAY_DAY
		chmod a+r  $TMP_HTML_DIR/historical/$YESTERDAY_YEAR/$YESTERDAY_MONTH/$YESTERDAY_DAY/*


		ssh_attacks $HTML_DIR/historical/$YESTERDAY_YEAR/$YESTERDAY_MONTH/$YESTERDAY_DAY _$YESTERDAY_YEAR $PATH_TO_VAR_LOG "$YESTERDAY_YEAR-$YESTERDAY_MONTH-$YESTERDAY_DAY"      "messages*" "current"
	fi
}


############################################################################
# Main 
#

echo -n "Started LongTail.sh at:"
date

HOSTNAME=$1
if [ "x$HOSTNAME" != "x" ] ;then
	echo "hostname set to $HOSTNAME"
else
	# I'm relying on "//" being the same as "/"
	# in unix :-)
	HOSTNAME="/"
fi

init_variables
read_local_config_file

if [ ! -d $HTML_DIR/$HOSTNAME ] ; then
	echo "Can not find $HTML_DIR/$HOSTNAME making it  now"
	mkdir $HTML_DIR/$HOSTNAME
	chmod a+rx $HTML_DIR/$HOSTNAME
	cp $HTML_DIR/index.shtml $HTML_DIR/$HOSTNAME
	chmod a+r $HTML_DIR/$HOSTNAME/index.shtml
	cp $HTML_DIR/index-long.shtml $HTML_DIR/$HOSTNAME
	chmod a+r $HTML_DIR/$HOSTNAME/index-long.shtml
	cp $HTML_DIR/graphics.shtml $HTML_DIR/$HOSTNAME
	chmod a+r $HTML_DIR/$HOSTNAME/graphics.shtml
fi

HTML_DIR="$HTML_DIR$HOSTNAME"
echo "HTML_DIR is $HTML_DIR"

echo "DEBUG is set to:$DEBUG"

change_date_date_in_index $HTML_DIR $YEAR

DATE=`date +"%b %e"` # THIS IS TODAY
DATE=`date +"%Y-%m-%d"` # THIS IS TODAY

if [ $DO_SSH  == 1 ] ; then do_ssh ; fi
# if [ $DO_HTTPD  == 1 ] ; then do_httpd ; fi

set_permissions  $HTML_DIR 
create_historical_copies  $HTML_DIR

make_daily_attacks_chart

# Calling a separate perl script to analyze the attack patterns
# This really should be the last thing run, as gosh knows what
# directory it may leave you in....
# echo "Trying to run SCRIPT_DIR/LongTail_analyze_attacks.pl now"
# Turned off for debugging and tuning $SCRIPT_DIR/LongTail_analyze_attacks.pl 2> /dev/null
echo -n "Done with LongTail.sh at:"
date
echo "Starting analysis now"
if [ "x$HOSTNAME" == "x/" ] ;then
	echo "hostname is not set, running analyze now"
	$SCRIPT_DIR/LongTail_analyze_attacks.pl $HOSTNAME 2> /dev/null
fi

exit
