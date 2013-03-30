package AN::Tools::Alert;

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Alert.pm";


sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Alert->new()\n";
	my $class = shift;
	
	my $self = {
		NO_FATAL_ERRORS		=>	0,
		SILENCE_WARNINGS	=>	0,
		ERROR_STRING		=>	"",
		ERROR_CODE		=>	0,
		OS_VALUES		=>	{
			DIRECTORY_DELIMITER	=>	"/",
		},
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

# Later, this will support all the translation and logging methods. For now,
# just print the error and exit;
sub error
{
	my $self  = shift;
	my $param = shift;
	
	# Clear any prior errors.
# 	$self->_set_error;
	my $an = $self->parent;
	
	# Setup default values
	my ($fatal, $title, $title_args, $message, $message_args, $code, $file, $line);
	
	# See if I am getting parameters is a hash reference or directly as
	# element arrays.
	if (ref($param))
	{
		# Called via a hash ref, good.
		$fatal  	= $param->{fatal}		? $param->{fatal}		: 1;
		$title  	= $param->{title}		? $param->{title}		: $an->String->get({key => "an_0004"});
		$title_args	= $param->{title_args}		? $param->{title_args}		: "";
		$message	= $param->{message}		? $param->{message}		: $an->String->get({key => "an_0005"});
		$message_args	= $param->{message_args}	? $param->{message_args}	: "";
		$code   	= $param->{code}		? $param->{code}		: 1;
		$file		= $param->{file}		? $param->{file}		: $an->String->get({key => "an_0006"});
		$line		= $param->{line}		? $param->{line}		: "";
		#print "$THIS_FILE ".__LINE__."; fatal: [$fatal], title: [$title], title_args: [$title_args], message: [$message], message_args: [$message_args], code: [$code], file: [$file], line: [$line]\n";
	}
	else
	{
		# Called directly.
		$fatal		= $param ? $param : 1;
		$title		= shift;
		$title_args	= shift;
		$message	= shift;
		$message_args	= shift;
		$code		= shift;
		$file		= shift;
		$line		= shift;
		#print "$THIS_FILE ".__LINE__."; fatal: [$fatal], title: [$title], title_args: [$title_args], message: [$message], message_args: [$message_args], code: [$code], file: [$file], line: [$line]\n";
	}
	
	# If the 'code' is empty and 'message' is "error_\d+", strip that code
	# off and use it as the error code.
	#print "$THIS_FILE ".__LINE__."; code: [$code], message: [$message]\n";
	if ((not $code) && ($message =~ /error_(\d+)/))
	{
		$code = $1;
		#print "$THIS_FILE ".__LINE__."; code: [$code], message: [$message]\n";
	}
	
	# If the title is a key, translate it.
	#print "$THIS_FILE ".__LINE__."; title: [$title]\n";
	if ($title =~ /^\w+_\d+$/)
	{
		$title = $an->String->get({
			key		=>	$title,
			variables	=>	$title_args,
		});
		#print "$THIS_FILE ".__LINE__."; title: [$title]\n";
	}
	
	# If the message is a key, translate it.
	#print "$THIS_FILE ".__LINE__."; message: [$message]\n";
	if ($message =~ /^\w+_\d+$/)
	{
		$message = $an->String->get({
			key		=>	$message,
			variables	=>	$message_args,
		});
		#print "$THIS_FILE ".__LINE__."; message: [$message]\n";
	}
	
	# Set my error string
	my $fatal_heading = $fatal ? $an->String->get({key => "an_0002"}) : $an->String->get({key => "an_0003"});
	#print "$THIS_FILE ".__LINE__."; fatal_heading: [$fatal_heading]\n";
	
	my $readable_line = $an->Readable->comma($line);
	#print "$THIS_FILE ".__LINE__."; readable_line: [$readable_line]\n";
	
	my $error         = "\n".$an->String->get({
		key		=>	"an_0007",
		variable	=>	[$code, $fatal_heading, $file, $readable_line, $title, $message],
	})."\n\n";
	#print "$THIS_FILE ".__LINE__."; error: [$error]\n";
	
	# Set the internal error flags
	$self->_set_error($error);
	$self->_set_error_code($code);
	
	# Append "exiting" to the error string if it is fatal.
	if ($fatal)
	{
		# Don't append this unless I really am exiting.
		$error .= $an->String->get({key => "an_0008"})."\n";
	}
	
	# Write a copy of the error to the log.
	$an->Log->entry({
		level		=>	1,
		raw		=>	$error,
	});
	
	# Don't actually die, but do print the error, if fatal errors have been
	# globally disabled (as is done in the tests).
	if ($self->no_fatal_errors == 0)
	{
		#$error =~ s/\n/<br \/>\n/g;
		print "$error\n" if not $self->no_fatal_errors;
		$self->_nice_exit($code);
	}
	
	return ($code);
}

# Later, this will support all the translation and logging methods. For now,
# just print the warning and return;
sub warning
{
	my $self  = shift;
	my $param = shift;
	
	# Clear any prior errors.
	$self->_set_error;
	my $an = $self->parent;
	
	# Setup default values
	my $title   = "";
	my $message = "";
	my $code    = 1;
	my $file    = "";
	my $line    = 0;
	
	# See if I am getting parameters is a hash reference or directly as
	# element arrays.
	if (ref($param))
	{
		# Called via a hash ref, good.
		$title   = $param->{title}   ? $param->{title}   : "no title";
		$message = $param->{message} ? $param->{message} : "no message";
		$code    = $param->{code}    ? $param->{code}    : 1;
		$file	 = $param->{file}    ? $param->{file}    : "unknown file";
		$line	 = $param->{line}    ? $param->{line}    : 0;
	}
	else
	{
		# Called directly.
		$title   = $param;
		$message = shift;
		$code    = shift;
		$file	 = shift;
		$line	 = shift;
	}
	
	# Set my warning string. Later, write this to the log and to STDOUT.
	my $heading =  "Warning";
	my $warning =  "-=] $code - $heading [=-\n";
	$warning    .= "-=] In file: [$file], at line: [".$an->Readable->comma($line)."].\n";
	$warning    .= "-=] $title [=-\n";
	$warning    .= "$message\n";
	
	print $warning;
	
	return (1);
}

# This stops the 'warning' method from printing to STDOUT. It will still print
# to the log though (once that's implemented).
sub silence_warnings
{
	my $self  = shift;
	my $param = shift;
	
	# Have to check if defined because '0' is valid.
	if (defined $param->{set})
	{
		$self->{SILENCE_WARNINGS} = $param->{set} if (($param->{set} == 0) || ($param->{set} == 1));
	}
	
	return ($self->{SILENCE_WARNINGS});
}

# This un/sets the prevention of errors being fatal.
sub no_fatal_errors
{
	my $self  = shift;
	my $param = shift;
	
	# Have to check if defined because '0' is valid.
	if (defined $param->{set})
	{
		$self->{NO_FATAL_ERRORS} = $param->{set} if (($param->{set} == 0) || ($param->{set} == 1));
	}
	
	return ($self->{NO_FATAL_ERRORS});
}

# This returns an error message if one is set.
sub _error_string
{
	my $self = shift;
	return $self->{ERROR_STRING};
}

# This returns an error code if one is set.
sub _error_code
{
	my $self = shift;
	return $self->{ERROR_CODE};
}

# This simply sets the error string method. Calling this method with an empty
# but defined string will clear the error message.
sub _set_error
{
	my $self  = shift;
	my $error = shift;
	
	# This is a bit of a cheat, but it saves a call when a method calls
	# this just to clear the error message.
	if ($error)
	{
		$self->{ERROR_STRING} = $error;
	}
	else
	{
		$self->{ERROR_STRING} = "";
		$self->{ERROR_CODE}   = 0;
	}
	
	return $self->{ERROR_STRING};
}

# This simply sets the error code method. Calling this method with an empty
# but defined string will clear the error code.
sub _set_error_code
{
	my $self  = shift;
	my $error = shift;
	
	$self->{ERROR_CODE} = $error ? $error : "";
	
	return $self->{ERROR_CODE};
}

# This will handle cleanup prior to exit.
sub _nice_exit
{
	my $self       = shift;
	my $error_code = $_[0] ? shift : 1;
	
	exit ($error_code);
}

1;
