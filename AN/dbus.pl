#!/usr/bin/perl
# This is the DBus daemon for AN::Tools.
#
# ToDo: none.
# 

use warnings;
use strict;
my $THIS_FILE="dbus.pl";

use AN::Tools;
my $an=AN::Tools->new({'_skip_dbus'=>1});

# Load my DBus modules.
$an->_load_net_dbus();
$an->_load_net_dbus_service();
$an->_load_net_dbus_reactor();

# This is the AN::Tools::DBus module section.
package AN::Tools::DBus;

# Catch signals. The most important one is ALRM as that is trapped by the
# call to 'alarm' to close this daemon when the timeout period has elapsed.
$SIG{HUP}=\&catch_sig;
$SIG{INT}=\&catch_sig;
$SIG{TERM}=\&catch_sig;
$SIG{ALRM}=\&catch_sig;

##############################################################################
# The methods below are used internally. DBus methods are further below.     #
##############################################################################

# This is the constructor method.
sub new
{
	my $class = shift;
	my $service = shift;
	my $self = $class->SUPER::new($service, "/com/alteeve/Tools");
	bless $self, $class;
	
	# This is how many seconds after the last call I will live for before
	# exiting this program.
# 	$self->{SHUTDOWN}{BUFFER}=600;
	$self->{SHUTDOWN}{BUFFER}=60;
	
	# This timeout is set for the alarm when a method is first called. It
	# should be long enough to out-live any realistic process. Once a
	# method completes, the 'SHUTDOWN_BUFFER' is reset.
# 	$self->{SHUTDOWN}{METHOD_CALL_BUFFER}=12000;
	$self->{SHUTDOWN}{METHOD_CALL_BUFFER}=300;
	
	# This is the method name that set the current-highest shutdown time.
	# Only it can reduce the shutdown time.
	$self->{SHUTDOWN}{LOCKED_BY}="";
	
	# This records the current shutdown time.
	$self->{SHUTDOWN}{WHEN}=time;
	
	# This is a hash reference that will hold the file handle(s) of the
	# log file(s) in use.
	$self->{LOG_FILE_HANDLES}={};
	
	# If set true, log filehandles will be made hot (that is, buffering
	# will be disabled).
	$self->{MAKE_LOG_FILE_HANDLES_HOT}=1;
	
	# Set a timout alarm.
	$self->_set_alarm("new", "release");
	
	return $self;
}

# This handles signals sent to this daemon. Most importantly is ALRM as
# explained above.
sub catch_sig
{
	my $sig=shift;
# 	print "Caught sig: [$sig] at: [".time."].\n";
# 	print "Inactivity timeout reached, exiting AN::DBus daemon.\n" if $sig eq "ALRM";
	# I'm going to hang up, but I don't want to kill myself just yet.
	local $SIG{HUP} = 'IGNORE';
	# Kill all associated PIDs.
	kill('HUP', -$$);
	# Goodbye.
	exit;
}

# This takes a log file and checks to see if there is a handle for it. If there
# isn't, it will create one. In either case, the handle is returned. It also
# checks to see if the log file needs to be managed.
sub _log_file_handle
{
	my $self=shift;
	my $log_file=shift;
	my $handle="";
	
	# Check the log file to see if it needs to be managed.
	print "$THIS_FILE ".__LINE__."; Checking: [$log_file] to see if it needs maintenance.\n";
	my $needs_maintenance=$an->Log->check($log_file);
	print "$THIS_FILE ".__LINE__."; Maintenance already underway.\n" if $self->{MESSAGE}{$log_file}{BUFFER};
	if (($needs_maintenance) && (not $self->{MESSAGE}{$log_file}{BUFFER}))
	{
		print "$THIS_FILE ".__LINE__."; Maintenance needed! Initiating the log buffer during maintenance.\n";
		$self->{MESSAGE}{$log_file}{BUFFER}=1;
		
		# Do my maintenance. This will close and/or open the log file
		# handle.
		sleep 30;
		print "$THIS_FILE ".__LINE__."; Maintenance complete.\n";
		
		# If there are any messages in the buffer, flush them.
		$self->{MESSAGE}{$log_file}{ARRAY}=[];
		if (@{$self->{MESSAGE}{$log_file}{ARRAY}})
		{
			print "$THIS_FILE ".__LINE__."; Flushing the buffer.\n";
			print "Array: [$self->{MESSAGE}{$log_file}{ARRAY}]\n";
# 			foreach my $line (@{$self->{MESSAGE}{$log_file}{ARRAY}})
# 			{
# 				# I know this log file handle will exist
# 				# because the maintenance method will have
# 				# created it if needed.
# 				print $self->{LOG_FILE_HANDLES}{$log_file} $line;
# 			}
		}
		
		$self->{MESSAGE}{$log_file}{BUFFER}=0;
	}
	
	# Get the log file handle if needed.
	if (exists $self->{LOG_FILE_HANDLES}{$log_file})
	{
		$handle=$self->{LOG_FILE_HANDLES}{$log_file};
		print "$THIS_FILE ".__LINE__."; File handle found for log file: [$log_file]. It is: [".$self->{LOG_FILE_HANDLES}{$log_file}."]\n";
	}
	else
	{
		print "$THIS_FILE ".__LINE__."; No existing log file handle found for log file: [$log_file], I will create it now.\n";
		
		# Load IO::Handle
		$an->_load_io_handle() if not $an->_io_handle_loaded();
		
		# Create the log file handle.
		$handle=IO::Handle->new();
		my $shell_call=">>$log_file";
		
		# If I can't open the log file for writing, then I can't do a
		# normal error() call as it would trigger an infinite loop.
		open ($handle, "$shell_call") || die "The 'AN::Tools' dbus server was not able to open the log file: [$log_file]. The error was: $!";
		
		# Set the log file handle to UTF8 mode.
		if ($an->String->force_utf8)
		{
			print "$THIS_FILE ".__LINE__."; Forcing handle LOG_FILE_HANDLES::$log_file: [$self->{LOG_FILE_HANDLES}{$log_file}] to UTF8 encoding.\n";
			binmode $self->{LOG_FILE_HANDLES}{$log_file}, "encoding(utf8)";
		}
		
		# Record the file handle in the bless'ed hash.
		$self->{LOG_FILE_HANDLES}{$log_file}=$handle;
		print "$THIS_FILE ".__LINE__."; New handle: [$handle] (LOG_FILE_HANDLES::$log_file: [$self->{LOG_FILE_HANDLES}{$log_file}]).\n";
		
		# Make the log's file handle hot if requested to do so.
		if ($self->{MAKE_LOG_FILE_HANDLES_HOT})
		{
			my $ofh=select $self->{LOG_FILE_HANDLES}{$log_file};
			$|=1;
			select $ofh;
		}
	}
	
	print "$THIS_FILE ".__LINE__."; returning LOG_FILE_HANDLES::$log_file: [$self->{LOG_FILE_HANDLES}{$log_file}].\n";
	return($self->{LOG_FILE_HANDLES}{$log_file});
}

# This calls 'alarm' to either 'SHUTDOWN::METHOD_CALL_BUFFER' seconds into the
# future when a method is first called and then recalls alarm to
# 'SHUTDOWN::BUFFER' seconds when the method exits.
sub _set_alarm
{
	my $self=shift;
	my $method=shift;
	my $do=shift;
	
	print "$THIS_FILE ".__LINE__."; _set_alarm called by: [$method] doing: [$do] at the time of: [".time."]\n";
	if ($do eq "call")
	{
		# Newest call, set the method call buffer and record the method
		# name.
		alarm $self->{SHUTDOWN}{METHOD_CALL_BUFFER};
		$self->{SHUTDOWN}{METHOD}{$method}=(time+$self->{SHUTDOWN}{METHOD_CALL_BUFFER});
# 		print "$THIS_FILE ".__LINE__."; Alarm set to: [$self->{SHUTDOWN}{METHOD_CALL_BUFFER}] seconds in the future ($self->{SHUTDOWN}{METHOD}{$method})\n";
	}
	else
	{
		my $furthest_out=$self->{SHUTDOWN}{METHOD}{$method};
		my $reset_alarm=1;
		foreach my $key (keys %{$self->{SHUTDOWN}{METHOD}})
		{
			next if $key eq $method;
# 			print "$THIS_FILE ".__LINE__."; Checking if the method call: [$key] is the further into the future than this one.\n";
			if ($self->{SHUTDOWN}{METHOD}{$key} >= $furthest_out)
			{
				# Another method is holding this open.
				$reset_alarm=0;
# 				print "$THIS_FILE ".__LINE__."; It's older, cancelling the alarm reset.\n";
			}
		}
		# Delete this method's name from the list.
		delete $self->{SHUTDOWN}{METHOD}{$method};
		
		# If this was the furthest out record, reset the alarm.
		if ($reset_alarm)
		{
# 			print "$THIS_FILE ".__LINE__."; Reset the alarm to: [$self->{SHUTDOWN}{BUFFER}] seconds into the future.\n";
			alarm $self->{SHUTDOWN}{BUFFER};
		}
	}
}

# This private method only checks that Net::DBus::Object is loadable
if ($an->_is_net_dbus_object_loadable())
{
	eval 'use base qw(Net::DBus::Object);';
	print $@ if $@;
	$an->_net_dbus_object_loaded(1);
}
# use base qw(Net::DBus::Object);

if ($an->_is_net_dbus_exporter_loadable())
{
	eval 'use Net::DBus::Exporter qw(com.alteeve.Tools);';
	print $@ if $@;
	$an->_net_dbus_exporter_loaded(1);
}
# use Net::DBus::Exporter qw(com.alteeve.Tools);

##############################################################################
# The methods below are published on the DBus bus.                           #
##############################################################################

dbus_method("WriteToLog", ["string", "string"], ["bool"]);
sub WriteToLog
{
	my $self=shift;
	my $log_file=shift;
	my $message=shift;
	$self->_set_alarm("WriteToLog", "call");
	
	# Chomp the message, in case there is already a line wrap.
	print "$THIS_FILE ".__LINE__."; Log File: [$log_file], Message: [$message]\n";
	
	# Check to see if I have a handle on the log file and, if not, create
	# one.
	my $log_handle=$self->_log_file_handle($log_file);
	print "$THIS_FILE ".__LINE__."; log_handle: [$log_handle]\n";
	
	# If the buffer is enabled, store the message. Otherwise, write it to
	# the file handle.
	if ($self->{MESSAGE}{$log_file}{BUFFER})
	{
		print "$THIS_FILE ".__LINE__."; Buffering message in the array: [MESSAGE::${log_file}::ARRAY]\n";
		push @{$self->{MESSAGE}{$log_file}{ARRAY}}, $message;
	}
	else
	{
		print "$THIS_FILE ".__LINE__."; Writting the message to the log file: [${log_file}]\n";
		print $log_handle $message;
	}
	
	# Reset the shutdown time.
	$self->_set_alarm("WriteToLog", "release");
	return (1);
}

# Switch back to the 'main' package namespace.
package main;

# Connect to the session bus.
my $bus = Net::DBus->session();
# my $bus = Net::DBus->system();
my $service = $bus->export_service("com.alteeve.Tools");
my $object = AN::Tools::DBus->new($service);

# Start the reactor.
Net::DBus::Reactor->main->run();
