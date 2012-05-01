package AN::Tools::Alert;

use strict;
use warnings;

our $VERSION="0.1.001";
my $THIS_FILE="Alert.pm";


sub new
{
	my $class=shift;
	
	my $self={
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
	my $self=shift;
	my $parent=shift;
	
	$self->{HANDLE}{TOOLS}=$parent if $parent;
	
	return ($self->{HANDLE}{TOOLS});
}

# Later, this will support all the translation and logging methods. For now,
# just print the error and exit;
sub error
{
	my $self=shift;
	my $param=shift;
	
	# Clear any prior errors.
	$self->_set_error;
	my $an=$self->parent;
	
	# Setup default values
	my $fatal=1;
	my $title="";
	my $message="";
	my $code=1;
	my $file="";
	my $line=0;
	
	# See if I am getting parameters is a hash reference or directly as
	# element arrays.
	if (ref($param))
	{
		# Called via a hash ref, good.
		$fatal  =$param->{fatal}   ? $param->{fatal}   : 1;
		$title  =$param->{title}   ? $param->{title}   : "no title";
		$message=$param->{message} ? $param->{message} : "no message";
		$code   =$param->{code}    ? $param->{code}    : 1;
		$file	=$param->{file}    ? $param->{file}    : "unknown file";
		$line	=$param->{line}    ? $param->{line}    : 0;
	}
	else
	{
		# Called directly.
		$fatal  =$param;
		$title  =shift;
		$message=shift;
		$code   =shift;
		$file	=shift;
		$line	=shift;
	}
	
	# Set my error string
	my $heading=$fatal ? "Fatal Error" : "Non-Fatal Error";
	my $error="-=] $code - $heading [=-\n";
	$error.="-=] In file: [$file], at line: [".$an->Readable->comma($line)."].\n";
	$error.="-=] $title [=-\n";
	$error.="$message\n";
	$self->_set_error($error);
	$self->_set_error_code($code);
	if ($fatal)
	{
		# Don't append this unless I really am exiting.
		$error.="Exiting.";
	}
	
	if ($self->no_fatal_errors == 0)
	{
		print "$error\n" if not $self->no_fatal_errors;
		$self->_nice_exit($code);
	}
	return ($code);
}

# Later, this will support all the translation and logging methods. For now,
# just print the warning and return;
sub warning
{
	my $self=shift;
	my $param=shift;
	
	# Clear any prior errors.
	$self->_set_error;
	my $an=$self->parent;
	
	# Setup default values
	my $title="";
	my $message="";
	my $code=1;
	my $file="";
	my $line=0;
	
	# See if I am getting parameters is a hash reference or directly as
	# element arrays.
	if (ref($param))
	{
		# Called via a hash ref, good.
		$title  =$param->{title}   ? $param->{title}   : "no title";
		$message=$param->{message} ? $param->{message} : "no message";
		$code   =$param->{code}    ? $param->{code}    : 1;
		$file	=$param->{file}    ? $param->{file}    : "unknown file";
		$line	=$param->{line}    ? $param->{line}    : 0;
	}
	else
	{
		# Called directly.
		$title  =$param;
		$message=shift;
		$code   =shift;
		$file	=shift;
		$line	=shift;
	}
	
	# Set my warning string. Later, write this to the log and to STDOUT.
	my $heading="Warning";
	my $warning="-=] $code - $heading [=-\n";
	$warning.="-=] In file: [$file], at line: [".$an->Readable->comma($line)."].\n";
	$warning.="-=] $title [=-\n";
	$warning.="$message\n";
	
	print $warning;
	
	return (1);
}

# This stops the 'warning' method from printing to STDOUT. It will still print
# to the log though (once that's implemented).
sub silence_warnings
{
	my $self=shift;
	my $param=shift;
	
	# Have to check if defined because '0' is valid.
	if (defined $param->{set})
	{
		$self->{SILENCE_WARNINGS}=$param->{set} if (($param->{set} == 0) || ($param->{set} == 1));
	}
	
	return ($self->{SILENCE_WARNINGS});
}

# This un/sets the prevention of errors being fatal.
sub no_fatal_errors
{
	my $self=shift;
	my $param=shift;
	
	# Have to check if defined because '0' is valid.
	if (defined $param->{set})
	{
		$self->{NO_FATAL_ERRORS}=$param->{set} if (($param->{set} == 0) || ($param->{set} == 1));
	}
	
	return ($self->{NO_FATAL_ERRORS});
}

# This returns an error message if one is set.
sub _error_string
{
	my $self=shift;
	return $self->{ERROR_STRING};
}

# This returns an error code if one is set.
sub _error_code
{
	my $self=shift;
	return $self->{ERROR_CODE};
}

# This simply sets the error string method. Calling this method with an empty
# but defined string will clear the error message.
sub _set_error
{
	my $self=shift;
	my $error=shift;
	
	# This is a bit of a cheat, but it saves a call when a method calls
	# this just to clear the error message.
	if ($error)
	{
		$self->{ERROR_STRING}=$error;
	}
	else
	{
		$self->{ERROR_STRING}="";
		$self->{ERROR_CODE}=0;
	}
	
	return $self->{ERROR_STRING};
}

# This simply sets the error code method. Calling this method with an empty
# but defined string will clear the error code.
sub _set_error_code
{
	my $self=shift;
	my $error=shift;
	
	$self->{ERROR_CODE}=$error ? $error : "";
	
	return $self->{ERROR_CODE};
}

# This will handle cleanup prior to exit.
sub _nice_exit
{
	my $self=shift;
	my $error_code=$_[0] ? shift : 1;
	
	exit ($error_code);
}

1;