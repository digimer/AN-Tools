package AN::Tools::Log;

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Log.pm";


sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Log->new()\n";
	my $class=shift;
	
	my $self={
		LOG_LEVEL			=>	1,
		LOG_HANDLE			=>	"",
		LOG_FILE			=>	"",
		DEFAULT_LOG_FILE		=>	"/var/log/an_tools.log",
		LOG_ARCHIVES			=>	5,
		LOG_CYCLE_SIZE			=>	"1M",
		LOG_COMPRESSION			=>	"/bin/gzip",
		LOG_COMORESSION_SWITCHES	=>	"--rsyncable",
		LOG_COMORESSION_SUFFIX		=>	"gz",
		SHORT_TIMESTAMP			=>	1,
		LOG_CHOMP_HEAD			=>	500,
		CHOMP_HEAD_BUFFER		=>	16384,
		LOG_LOCK_FILE			=>	"/tmp/an_tools_log.lock",
	};
	
	bless $self, $class;
	
	return ($self);
}

# Get a handle on the AN::Tools object. I know that technically that is a
# sibling module, but it makes more sense in this case to think of it as a
# parent.
sub parent
{
	my $self   = shift;
	my $parent = shift;
	
	$self->{HANDLE}{TOOLS} = $parent if $parent;
	
	return ($self->{HANDLE}{TOOLS});
}

# This checks the size of the log file and, when it reaches cycle_size(), calls
# cycle_log().
sub check
{
	my $self = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	$an->Alert->_set_error;
	
	# Either get the passed in log file or use the default one.
	my $log_file = $_[0] ? shift : $an->Log->file;
	
	# Do my checks.
	my $size         = 0;
	my $cycle_needed = 0;
# 	print "$THIS_FILE ".__LINE__."; Log file: [$log_file]\n";
	if (-e $log_file)
	{
		# File exists, check it's byte size.
# 		print "$THIS_FILE ".__LINE__."; Log file exists, checking it's size.\n";
		if (-l $log_file)
		{
			# Symlink, use lstat
# 			print "$THIS_FILE ".__LINE__."; Log file is a symlink, using 'lstat'.\n";
			($size)=(lstat $log_file)[7];
		}
		elsif (-f $log_file)
		{
			# Normal file, use 'stat'
# 			print "$THIS_FILE ".__LINE__."; Log file is normal, using 'stat'.\n";
			($size)=(stat $log_file)[7];
		}
	}
	else
	{
# 		print "$THIS_FILE ".__LINE__."; Log file doesn't exist.\n";
	}
# 	print "$THIS_FILE ".__LINE__."; I read the size as: [$size] (max allowed size is: [".$an->Log->cycle_size()."])\n";
	if ($size >= $an->Log->cycle_size())
	{
		# The file is too large, cycle/archive it.
# 		print "$THIS_FILE ".__LINE__."; Log file size exceeds maximum, initiating 'cycle' method.\n";
		$cycle_needed = 1;
	}
	
	return ($cycle_needed);
}

# This handles cycling the log file plus archiving when enabled.
sub _cycle
{
	my $self = shift;
	
	# This just makes the code more consistent.
	my $an   = $self->parent;
	$an->Alert->_set_error;
	
	# Lock the log file. This is done in an 'eval' because I don't load
	# Fcntl at compile time, Without the 'eval' wrapper the compiler would
	# gak complaining of bareword errors.
	### MADI: Test what happens when two scripts have open filehandles to
	###       the same file and one does a LOCK_EX. Does the other fh just
	###       wait?
	$an->_load_fcntl() if not $an->_fcntl_loaded();
	my $log_fh = $an->Log->get_handle();
	eval 'flock($log_fh,\'LOCK_EX\')';
	if ($@)
	{
		die "Failed to get an exclusive lock on the log file: [".$an->Log->file()."]. Error was: $!\n";
	}
	
	# Make sure the file pointer is at the end of the file in the case of
	# something been written to the file while it was being locked.
	seek($log_fh, 0, 2);
	
# 	my $lock=IO::Handle->new()
# 	open ($lock, ">$self->{LOG_LOCK_FILE}") || die "Failed to create log lock file: [$self->{LOG_LOCK_FILE}]\n";
# 	$lock->close;
	
	# First, am I archiving this file?
	if ($an->Log->archives > 0)
	{
		# I'm archiving. First thing to do is move the existing
		# archives out of the way. Start the loop down by one because I
		# will clobber the last entry regardless of whether it exists
		# or not.
		for (my $i = ($an->Log->archives - 1); $i >= 1; $i--)
		{
			my $from = $an->Log->file.".$i.".$an->Log->compression_suffix();
			my $to   = $an->Log->file.".".($i+1).".".$an->Log->compression_suffix();
			if (-e $from)
			{
				rename($from, $to) || $an->Alert->error({
					fatal	=>	1,
					title	=>	"'AN::Tools::Log->_cycle()' was not able to rename an archived log file.",
					message	=>	"The AN::Tools::Log method '_cycle' was not able to rename the archived log file: [$from] to: [$to]. The error was: $!",
					code	=>	35,
					file	=>	"$THIS_FILE",
					line	=>	__LINE__
				});
			}
		}
		
		# Now the old archives should be out of the way. To make sure
		# other existing file handles stay valid, I copy the log file
		# to it's new name and the 
	}
	else
	{
		# Nope, just delete X-number of lines from the top of the file
		# or blank if 'chomp_head()' returns 0.
		if ($an->Log->chomp_head > 0)
		{
			### This solution was provided by Shlomi Fish
			### <shlomif@iglu.org.il> via TPM. Thanks!
			# Chomp some lines off the head of the log file.
			my $log_file     = $an->Log->file();
			my ($dir, $file) = ($log_file =~ /(.*)\/(.*?)$/);
			
			# Setup the name of the temporary log file.
			my $write_file   = "$dir/.$file";
			
			my $in=IO::Handle->new();
			open ($in, "<$log_file") || $an->Alert->error({
				fatal	=>	1,
				title	=>	"'AN::Tools::Log->_cycle()' was not able to open the log file for reading.",
				message	=>	"The AN::Tools::Log method '_cycle' was not able to open the log file: [$log_file]. The error was: $!",
				code	=>	32,
				file	=>	"$THIS_FILE",
				line	=>	__LINE__
			});
			
			my $out=IO::Handle->new();
			open ($out, ">$write_file") || $an->Alert->error({
				fatal	=>	1,
				title	=>	"'AN::Tools::Log->_cycle()' was not able to open the temporary log file for writting.",
				message	=>	"The AN::Tools::Log method '_cycle' was not able to open the log file: [$write_file]. The error was: $!",
				code	=>	33,
				file	=>	"$THIS_FILE",
				line	=>	__LINE__
			});
			
			# Skip the given number of initial lines.
			for (1..$an->Log->chomp_head())
			{
				scalar(<$in>);
			}
			
			# Do a buffered read from the current log file into my
			# temporary log file.
			my $buffer_length = $an->Log->chomp_head_buffer();
			my $buffer;
			while (read($in, $buffer, $buffer_length))
			{
				print $out $buffer;
			}
			$in->close;
			$out->close;
			
			# Move the temporary log file over top of the real log
			# file, clobering it.
			rename($out, $in) || $an->Alert->error({
				fatal	=>	1,
				title	=>	"'AN::Tools::Log->_cycle()' was not able to rename an archived log file.",
				message	=>	"The AN::Tools::Log method '_cycle' was not able to rename the archived log file: [$out] to: [$in]. The error was: $!",
				code	=>	35,
				file	=>	"$THIS_FILE",
				line	=>	__LINE__
			});
		}
		else
		{
			# Blank the whole log file.
			$an->_load_io_handle() if not $an->_io_handle_loaded();
			my $write      = IO::Handle->new;
			my $shell_call = ">".$an->Log->file();
			open ($write, $shell_call) || $an->Alert->error({
				fatal	=>	1,
				title	=>	"'AN::Tools::Log->_cycle()' was not able to open the log file for writing.",
				message	=>	"The AN::Tools::Log method '_cycle' was not able to open the log file: [".$an->Log->file()."]. The error was: $!",
				code	=>	29,
				file	=>	"$THIS_FILE",
				line	=>	__LINE__
			});
			$write->close();
		}
	}
	
	# Remove the lock on the log.
	eval 'flock($log_fh,\'LOCK_UN\')';
	if ($@)
	{
		die "Failed to release the lock on the log file: [".$an->Log->file()."]. Error was: $!\n";
	}
# 	unlink $self->{LOG_LOCK_FILE};
	
	return (1);
}

# This sets or returns the log file to write log entries to. This is also the
# name + compression_suffix + sequence number used for the archives. This must
# be a fully defined path and file name. When cycling, the file name will be
# broken off from the path at the final '/'. When setting, a check is made to
# ensure that the directory the file will be created in exists.
sub file
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	#print "$THIS_FILE ".__LINE__."; In AN::Log->file()\n";
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# Check and set if needed.
	#print "$THIS_FILE ".__LINE__."; Set: [$set]\n" if $set;
	if ($set)
	{
		my ($dir, $file) = ($set =~ /(.*)\/(.*?)$/);
		#print "$THIS_FILE ".__LINE__."; dir: [$dir], file: [$file]\n" if $set;
		if (not -d $dir)
		{
			#print "$THIS_FILE ".__LINE__."; dir: [$dir] doesn't exist.\n" if $set;
			# Directory doesn't exist.
			$an->Alert->error({
				fatal	=>	1,
				title	=>	"Directory Not Found",
				message	=>	"The 'AN::Tools::Log' module's 'file()' method parsed: [$set] as the directory: [$dir] and the file: [$file]. This directory was not found. Please create this directory and make sure it is writable by the user: [".getpwuid($<)."] or group: [".getgrgid($()."] (UID: [$<], GID: [$(]).",
				code	=>	25,
				file	=>	"$THIS_FILE",
				line	=>	__LINE__
			});
			return (undef);
		}
		if (not -w $dir)
		{
			# Directory doesn't exist.
			print "$THIS_FILE ".__LINE__."; dir: [$dir] not writeable\n" if $set;
			$an->Alert->error({
				fatal	=>	1,
				title	=>	"Directory Not Writeable",
				message	=>	"The 'AN::Tools::Log' module's 'file()' method parsed: [$set] as the directory: [$dir] and the file: [$file]. This directory exists but is not writable by the user: [".getpwuid($<)."] or group: [".getgrgid($()."] (UID: [$<], GID: [$(]). Please update the permissions or choose another directory.",
				code	=>	26,
				file	=>	"$THIS_FILE",
				line	=>	__LINE__
			});
			return (undef);
		}
		if ((-e $set) && (not -w $set))
		{
			# File already exists but it is not writable.
			$an->Alert->error({
				fatal	=>	1,
				title	=>	"File Not Writeable",
				message	=>	"The 'AN::Tools::Log' module's 'file()' method parsed: [$set] as the directory: [$dir] and the file: [$file]. This log file exists but it is not writable by the user: [".getpwuid($<)."] or group: [".getgrgid($()."] (UID: [$<], GID: [$(]). Please update the permissions or choose another file.",
				code	=>	27,
				file	=>	"$THIS_FILE",
				line	=>	__LINE__
			});
			return (undef);
		}
		$self->{LOG_FILE} = $set;
	}
	
# 	print "$THIS_FILE ".__LINE__."; Returning: [$self->{LOG_FILE}]\n";
	return ($self->{LOG_FILE});
}

# This sets and/or returns the the number of lines to delete from the top of
# the log file when I am not keeping archives but instead just spooling off the
# oldest records to maintain a given maximum size.
sub chomp_head
{
	my $self=shift;
	my $set=shift if defined $_[0];
	
	my $an=$self->parent;
	$an->Alert->_set_error;
	
	if (defined $set)
	{
		# Make sure I got an integer.
		if ($set =~ /\D/)
		{
			$an->Alert->error({
				fatal	=>	1,
				title	=>	"Illegal argument",
				message	=>	"The 'AN::Tools::Log' module's 'chomp_head()' method was passed a non-integer argument: [$set]. Only integers are valid.",
				code	=>	30,
				file	=>	"$THIS_FILE",
				line	=>	__LINE__
			});
			# Return nothing in case the user is blocking fatal
			# errors.
			return (undef);
		}
		
		# The user may be blanking this.
		if ($set)
		{
			$self->{LOG_CHOMP_HEAD} = $set;
		}
		else
		{
			# Disable. This will blank the log file when it reaches
			# it's maximum size.
			$self->{LOG_CHOMP_HEAD} = 0;
		}
	}
	
	return ($self->{LOG_CHOMP_HEAD});
}

# This sets and/or returns the the buffer size in bytes uses when reading from
# the real log file for writting into the temporary log file.
sub chomp_head_buffer
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	my $an   = $self->parent;
	$an->Alert->_set_error;
	
	if (defined $set)
	{
		# Make sure I got an integer.
		if ($set =~ /\D/)
		{
			$an->Alert->error({
				fatal	=>	1,
				title	=>	"Illegal argument",
				message	=>	"The 'AN::Tools::Log' module's 'chomp_head_buffer()' method was passed a non-integer argument: [$set]. Only integers are valid.",
				code	=>	34,
				file	=>	"$THIS_FILE",
				line	=>	__LINE__
			});
			# Return nothing in case the user is blocking fatal
			# errors.
			return (undef);
		}
		
		# The user may be blanking this.
		if ($set)
		{
			$self->{CHOMP_HEAD_BUFFER} = $set;
		}
		else
		{
			# Disable. This will blank the log file when it reaches
			# it's maximum size.
			$self->{CHOMP_HEAD_BUFFER} = 0;
		}
	}
	
	return ($self->{CHOMP_HEAD_BUFFER});
}

# This sets and/or returns the command line switches to use for the compression
# program. NO SANITY CHECKS ARE DONE! Use with care. Recognized compression
# program has sane defaults set.
sub compression_switches
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	my $an   = $self->parent;
	$an->Alert->_set_error;
	
	if (defined $set)
	{
		# The user may be blanking this.
		if ($set)
		{
			$self->{LOG_COMORESSION_SWITCHES} = $set;
		}
		else
		{
			# Disable.
			$self->{LOG_COMORESSION_SWITCHES} = "";
		}
	}
	
	return ($self->{LOG_COMORESSION_SWITCHES});
}

# This sets and/or returns the file suffix for the given compression program.
# For example, this should be 'gz' when gzip is used or 'bz' when bzip2 is
# used.
sub compression_suffix
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	my $an   = $self->parent;
	$an->Alert->_set_error;
	
	if (defined $set)
	{
		# The user may be blanking this.
		if ($set)
		{
			$self->{LOG_COMORESSION_SUFFIX} = $set;
		}
		else
		{
			# Disable.
			$self->{LOG_COMORESSION_SUFFIX} = "";
		}
	}
	
	return ($self->{LOG_COMORESSION_SUFFIX});
}

# This set and/or returns the external program to use when compressing archived
# log files. If unset, no compression is done.
sub compression
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	my $an   = $self->parent;
	$an->Alert->_set_error;
	
	if (defined $set)
	{
		# The user may be blanking this.
		if ($set)
		{
			# Only test is to make sure the path and program name
			# are valid and executable.
			if (not -e $set)
			{
				# Program not found.
				$an->Alert->error({
					fatal	=>	1,
					title	=>	"Program not found",
					message	=>	"The 'AN::Tools::Log' module's 'compression()' method was passed: [$set] to use as the compression program. This was not found. The method requires that the full path and program name are set to ensure that the compression program can be used when no PATH environment variable exists.",
					code	=>	23,
					file	=>	"$THIS_FILE",
					line	=>	__LINE__
				});
				return (undef);
			}
			if (not -x $set)
			{
				# Program not found.
				$an->Alert->error({
					fatal	=>	1,
					title	=>	"Program not executable",
					message	=>	"The 'AN::Tools::Log' module's 'compression()' method was passed: [$set] to use as the compression program but it is not executable. Please check the permissions on the compression program.",
					code	=>	24,
					file	=>	"$THIS_FILE",
					line	=>	__LINE__
				});
				return (undef);
			}
			$self->{LOG_COMPRESSION} = $set;
		}
		else
		{
			# Disable.
			$self->{LOG_COMPRESSION} = "";
		}
	}
	
	return ($self->{LOG_COMPRESSION});
}

# This sets or returns the number of log archives to keep.
sub cycle_size
{
	my $self=shift;
	my $set=shift if defined $_[0];
	
	my $an=$self->parent;
	$an->Alert->_set_error;
	
	# The first time this is called, if 'set' isn't set, I check to see if
	# the default value has a non-digit character. If so, I assume the
	# default log size needs to be translated into bytes.
	if ((not defined $set) && ($self->{LOG_CYCLE_SIZE} =~ /\D/))
	{
		$set=$self->{LOG_CYCLE_SIZE};
	}
	
	if (defined $set)
	{
		# There is no sense doing the fairly complex checking if the
		# passed size is valid because AN::Tools::Readable already does
		# all the checks. Instead, I will just check for an error state
		# and die if error code 7, 8 or 10 are returned.
		my $fatal_was           = $an->Alert->no_fatal_errors();
		$an->Alert->no_fatal_errors({set=>1});
		$self->{LOG_CYCLE_SIZE} = $an->Readable->hr_to_bytes($set);
		$an->Alert->no_fatal_errors({set=>$fatal_was});
		if ($an->error_code)
		{
			# Something went wrong...
			$an->Alert->error({
				fatal	=>	1,
				title	=>	"Illegal argument",
				message	=>	"The 'AN::Tools::Log' module's 'cycle_size()' method triggered an error in the 'AN::Tools::Reaadable' module's 'hr_to_readable' method while trying to convert: [$set] into bytes. The error code returned was: [".$an->error_code."]. Please see the log file or 'perldoc AN::Tools::Alert' for more details on this error code.",
				code	=>	22,
				file	=>	"$THIS_FILE",
				line	=>	__LINE__
			});
			# Return nothing in case the user is blocking fatal
			# errors.
			return (undef);
		}
	}
	
	return ($self->{LOG_CYCLE_SIZE});
}

# This sets or returns the number of log archives to keep.
sub archives
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	my $an   = $self->parent;
	$an->Alert->_set_error;
	
	if ((defined $set) && ($set =~ /\D/))
	{
		$an->Alert->error({
			fatal	=>	1,
			title	=>	"Illegal argument",
			message	=>	"The 'AN::Tools::Log' module's 'archives()' method was passed a non-integer argument: [$set]. Only integers are valid.",
			code	=>	21,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}
	
	$self->{LOG_ARCHIVES} = $set if defined $set;
	
	print "$THIS_FILE ".__LINE__."; Returning: [$self->{LOG_ARCHIVES}]\n";
	return ($self->{LOG_ARCHIVES});
}

# This sets or returns whether short time stamps are used in log entires.
sub short_timestamp
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	my $an   = $self->parent;
	$an->Alert->_set_error;
	
	if ((defined $set) && (($set ne "0") && ($set ne "1")))
	{
		$an->Alert->error({
			fatal	=>	1,
			title	=>	"Illegal argument",
			message	=>	"The 'AN::Tools::Log' module's 'short_timestamp()' method was passed an illegal argument: [$set]. Only '0' and '1' are valid.",
			code	=>	20,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}
	
	$self->{SHORT_TIMESTAMP} = $set if defined $set;
	
	return ($self->{SHORT_TIMESTAMP});
}

# This sets or returns the log level.
sub level
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	my $an   = $self->parent;
	$an->Alert->_set_error;
	
	if ((defined $set) && ($set =~ /\D/))
	{
		$an->Alert->error({
			fatal	=>	1,
			title	=>	"Illegal argument",
			message	=>	"The 'AN::Tools::Log' module's 'level()' method was passed a non-integer argument: [$set]. Only integers are valid.",
			code	=>	19,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}
	
	$self->{LOG_LEVEL} = $set if defined $set;
	
	return ($self->{LOG_LEVEL});
}

# This returns the log file handle and, when it does not yet exists, it creates
# the file handle.
sub get_handle
{
	my $self = shift;
	
	my $an   = $self->parent;
	$an->Alert->_set_error;
	
	# Make sure that IO::Handle is loaded.
	$an->_load_io_handle() if not $an->_io_handle_loaded();
	
	# Set the log file if it's not yet been set.
	$an->Log->file($self->{DEFAULT_LOG_FILE}) if not $an->Log->file();
	
	# Open the log file if it's not already open.
	if (not $self->{LOG_HANDLE})
	{
		my $write      = IO::Handle->new;
		my $shell_call = $an->Log->file();
		open ($write, ">>", $shell_call) || $an->Alert->error({
			fatal	=>	1,
			title	=>	"'AN::Tools::Log->get_handle()' was not able to open the log file for writing.",
			message	=>	"The AN::Tools::Log method 'get_handle' was not able to open the log file: [".$an->Log->file()."]. The error was: $!",
			code	=>	29,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		# Make the log handle "hot" (turn off buffering).
		$write->autoflush(1);
		$self->{LOG_HANDLE} = $write;
	}
	
	return ($self->{LOG_HANDLE});
}

# This does all the work of recording an entry in the log file when
# appropriate.
sub entry
{
	my $self  = shift;
	my $param = shift;
	
	my $an    = $self->parent;
	$an->Alert->_set_error;
	
	# Check if the log file lock is available. If so, wait until it's gone.
	### MADI: Make 'LOG_LOCK_FILE' a setable method.
# 	while (-e $self->{LOG_LOCK_FILE})
# 	{
# 		$sleep 2;
# 	}
	### MADI: Actually, make sure that this properly checks for 'flock' and
	###       waits for it to be released.
	
	# Setup my variables.
	my ($string, $log_level, $file, $line, $title_key, $title_vars, $message_key, $message_vars, $language, $filehandle, $raw);
	
	# Now see if the user passed the values in a hash reference or
	# directly.
	if (ref($param) eq "HASH")
	{
		# Values passed in a hash, good.
		$log_level    = $param->{log_level}                    ? $param->{log_level}    : 0;
		$file         = $param->{file}                         ? $param->{file}         : "";
		$line         = $param->{line}                         ? $param->{line}         : "";
		$title_key    = $param->{title_key}                    ? $param->{title_key}    : "";
		$title_vars   = ref($param->{title_vars}) eq "ARRAY"   ? $param->{title_vars}   : "";
		$message_key  = $param->{message_key}                  ? $param->{message_key}  : "";
		$message_vars = ref($param->{message_vars}) eq "ARRAY" ? $param->{message_vars} : "";
		$language     = $param->{language}                     ? $param->{language}     : $an->default_language;
		$filehandle   = $param->{filehandle}                   ? $param->{filehandle}   : $an->Log->get_handle;
		$raw          = $param->{raw}                          ? $param->{raw}          : "";
	}
	else
	{
		# Values passed directly.
		$log_level    = defined $param ? $param : 0;
		$file         = defined $_[0]  ? $_[0]  : "";
		$line         = defined $_[1]  ? $_[1]  : "";
		$title_key    = defined $_[2]  ? $_[2]  : "";
		$title_vars   = defined $_[3]  ? $_[3]  : "";
		$message_key  = defined $_[4]  ? $_[4]  : "";
		$message_vars = defined $_[5]  ? $_[5]  : "";
		$language     = defined $_[6]  ? $_[6]  : $an->default_language;
		$filehandle   = defined $_[7]  ? $_[7]  : $an->Log->get_handle;
		$raw          = defined $_[8]  ? $_[8]  : "";
	}
	
	# Return if the log level of the message is less than the current
	# system log level.
	return(1) if $log_level > $an->Log->level;
	
	# Check to see if it's time to cycle the log file and, if so, do the
	# cycle.
	$an->Log->check();
	
	# Get the current data and time.
	my ($now_date, $now_time) = $an->Get->date_and_time();
	
	# If 'raw' is set, just write to the file handle. Otherwise, parse the
	# entry.
	if ($raw)
	{
		$string = "$now_date $now_time\n----\n$raw\n----";
	}
	else
	{
		# Create the log string.
		my $title   = $an->String->get({
			key		=>	$title_key,
			variable	=>	$title_vars,
			language	=>	$language,
			filehandle	=>	$filehandle,
		});
		my $message = $an->String->get({
			key		=>	$message_key,
			variable	=>	$message_vars,
			language	=>	$language,
			filehandle	=>	$filehandle,
		});
		
		$string     = "$now_date $now_time - $file \@ $line: [ $title ] - $message";
	}

	# Write the entry
# 	print "$THIS_FILE ".__LINE__."; string: [$string]\n";
	print $filehandle $string, "\n";
	
	# MADI: Have this return the exact string written to the log, if any.
	return($string);
}

1;
