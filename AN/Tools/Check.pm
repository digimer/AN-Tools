package AN::Tools::Check;

use strict;
use warnings;

our $VERSION="0.1.001";
my $THIS_FILE="Check.pm";


# The constructor
sub new
{
	my $class=shift;
	
	my $self={
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

# This private method is called my AN::Tools' constructor at startup and checks
# the underlying OS and sets any internal variables as needed. It takes no
# arguments and simply returns '1' when complete.
sub _os
{
	my $self=shift;
	
	my $an=$self->parent;
	
	if (lc($^O) eq "linux")
	{
		# Some linux variant
		$an->_directory_delimiter("/");
	}
	elsif (lc($^O) eq "mswin32")
	{
		# Some windows variant.
		$an->_directory_delimiter("\\");
	}
	else
	{
		# Huh?
		$an->Alert->warning({
			title		=>	"Unknown OS",
			message		=>	"The detected operating system: [$^O] is not recognized by AN::Tools. Please send this error message and your operating system details to AN! (http://alteeve.com) so that we can add support for your OS. For now, I will proceed with Linux-type settings. This may not work.",
			code		=>	43,
			file		=>	"$THIS_FILE",
			line		=>	__LINE__
		});
		$an->_directory_delimiter("/");
	}
	
	return (1);
}

1;
