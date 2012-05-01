package AN::Tools;
# This is the "root" package that manages the sub modules and controls access
# to their methods.
# 
# Dedicated to Leah Kubik who helped me back in the early days of TLE-BU.
# 

# Search engine that assigns a "word" to a given page that best defines that word.
# Then give each page a "rank" based on the "words" pages that link to and from that page.
# (weighted, outbound links worth ~1/10th an inbound link)

BEGIN
{
	our $VERSION="0.1.001";
}

use strict;
use warnings;
my $THIS_FILE="Tools.pm";

# Setup for UTF-8 mode.
use utf8;
$ENV{'PERL_UNICODE'}=1;

# I intentionally don't use EXPORT, @ISA and the like because I want my
# "subclass"es to be accessed in a somewhat more OO style. I know some may
# wish to strike me down for this, but I like the idea of accessing methods
# via their containing module's name. (A La: $an->Module->method rather than
# $an->method).
use AN::Tools::Alert;
use AN::Tools::Check;
use AN::Tools::Log;
use AN::Tools::Math;
use AN::Tools::Readable;
use AN::Tools::Storage;
use AN::Tools::String;

# The constructor through which all other module's methods will be accessed.
sub new
{
	my $class=shift;
	my $param=shift;
	
	my $self={
		DBUS				=>	{
			ADDRESS				=>	"",
			BUS				=>	"",
			SERVICE				=>	"",
			OBJECT				=>	"",
		},
		HANDLE				=>	{
			ALERT				=>	AN::Tools::Alert->new(),
			CHECK				=>	AN::Tools::Check->new(),
			LOG				=>	AN::Tools::Log->new(),
			MATH				=>	AN::Tools::Math->new(),
			READABLE			=>	AN::Tools::Readable->new(),
			STORAGE				=>	AN::Tools::Storage->new(),
			STRING				=>	AN::Tools::String->new(),
		},
		LOADED				=>	{
			'Math::BigInt'			=>	0,
			'IO::Handle'			=>	0,
			'Net::DBus'			=>	0,
			'Net::DBus::Service'		=>	0,
			'Net::DBus::RemoteService'	=>	0,
			'Net::DBus::Reactor'		=>	0,
			'Net::DBus::Object'		=>	0,
			'Net::DBus::RemoteObject'	=>	0,
			'Net::DBus::Exporter'		=>	0,
			Fcntl				=>	0,
		},
		DATA				=>	{},
		ERROR_LIMIT			=>	10000,
		DEFAULT				=>	{
			CONFIG_FILE			=>	'AN::Tools/an.conf',
			LANGUAGE			=>	'en_CA',
			SEARCH_DIR			=>	\@INC,
		},
	};
	
	# Bless you!
	bless $self, $class;
	
	# This isn't needed, but it makes the code below more consistent with
	# and portable to other modules.
	my $an=$self;
	
	# This gets handles to my other modules that the child modules will use
	# to talk to other sibling modules.
	$self->Alert->parent($self);
	$self->Check->parent($self);
	$self->Log->parent($self);
	$self->Math->parent($self);
	$self->Readable->parent($self);
	$self->Storage->parent($self);
	$self->String->parent($self);
	
	# Check the operating system and set any OS-specific values.
	$self->Check->_os;
	
	# Before I do anything, read in values from the 'DEFAULT::CONFIG_FILE'
	# configuration file.
	$an->Storage->read_conf($self->{DEFAULT}{CONFIG_FILE});
	
	# Now I setup my log file and it's path. If the log directory starts
	# with the directory delimiter, I assume it is fully qualified and
	# only attach the log file name as a suffix. Otherwise, I assume it is
	# relative and start with the install directory.
	my $directory_delimiter=$an->_directory_delimiter();
	my $log_file=$an->data->{dir}{logs} =~ /^$directory_delimiter/ ? $an->data->{dir}{logs}.$an->data->{'log'}{file} : $an->data->{dir}{install}.$an->data->{dir}{logs}.$an->data->{'log'}{file};
	$an->Log->file($log_file);
	
	# Set passed parameters if needed.
	if (ref($param) eq "HASH")
	{
		### Local parameters
		# Set the default language.
		$self->default_language		($param->{default_language}) 		if $param->{default_language};
		$self->dbus_address		($param->{dbus_address}) 		if $param->{dbus_address};
		
		### AN::Tools::Readable parameters
		# Readable needs to be set before Log so that changes to
		# 'base2' are made before the default log cycle size is
		# interpreted.
		$self->Readable->base2		($param->{Readable}{base2}) 		if defined $param->{Readable}{base2};
		
		### AN::Tools::Log parameters
		# Set the log file.
		$self->Log->file		($param->{'log'}{file}) 		if defined $param->{'log'}{file};
		$self->Log->cycle_size		($param->{'log'}{cycle_size}) 		if defined $param->{'log'}{cycle_size};
		$self->Log->archives		($param->{'log'}{archives}) 		if defined $param->{'log'}{archives};
		$self->Log->compression		($param->{'log'}{compression}) 		if defined $param->{'log'}{compression};
		$self->Log->compression_switches($param->{'log'}{compression_switches}) if defined $param->{'log'}{compression_switches};
		$self->Log->compression_suffix	($param->{'log'}{compression_suffix}) 	if defined $param->{'log'}{compression_suffix};
		$self->Log->chomp_head		($param->{'log'}{chomp_head}) 		if defined $param->{'log'}{chomp_head};
		$self->Log->chomp_head_buffer	($param->{'log'}{chomp_head_buffer}) 	if defined $param->{'log'}{chomp_head_buffer};
		
		### AN::Tools::String parameters
		# Force UTF-8.
		$self->String->force_utf8	($param->{String}{force_utf8}) 		if defined $param->{String}{force_utf8};
	}
	
	# Call methods that need to be loaded at invocation of the module.
	$self->String->read_words();
	
	# Start the logger. This will create the log file if needed.
# 	$an->Log->
	
	# Connect to the DBus.
# 	print "$THIS_FILE ".__LINE__.": param->{'_skip_dbus'}: [$param->{'_skip_dbus'}]\n";
# 	$self->_connect_to_dbus() if not defined $param->{'_skip_dbus'};
	
	return ($self);
}

# This sets or returns the default language the various modules use when
# processing word strings.
sub default_language
{
	my $self=shift;
	my $set=shift if defined $_[0];
	
	# This could be set before any word files are read, so no checks are
	# done here.
	$self->{DEFAULT}{LANGUAGE}=$set if $set;
	
	return ($self->{DEFAULT}{LANGUAGE});
}

# This is a shortcut to the '$an->Alert->_error_string' method allowing for
# '$an->error' to be called, saving the caller typing.
sub error
{
	my $self=shift;
	return ($self->Alert->_error_string);
}

# This is a shortcut to the '$an->Alert->_error_code' method allowing for
# '$an->error_code' to be called, saving the caller typing.
sub error_code
{
	my $self=shift;
	return ($self->Alert->_error_code);
}

# Makes my handle to AN::Tools::Alert clearer when using this module to access
# it's methods.
sub Alert
{
	my $self=shift;
	
	return ($self->{HANDLE}{ALERT});
}

# Makes my handle to AN::Tools::Check clearer when using this module to access
# it's methods.
sub Check
{
	my $self=shift;
	
	return ($self->{HANDLE}{CHECK});
}

# This is the method used to access the main hash reference that all
# user-accessible values are stored in. This includes words, configuration file
# variables and so forth.
sub data
{
	my $self=shift;
	
	return ($self->{DATA});
}

# Makes my handle to AN::Tools::Log clearer when using this module to access
# it's methods.
sub Log
{
	my $self=shift;
	
	return ($self->{HANDLE}{LOG});
}

# Makes my handle to AN::Tools::Math clearer when using this module to access
# it's methods.
sub Math
{
	my $self=shift;
	
	return ($self->{HANDLE}{MATH});
}

# Makes my handle to AN::Tools::Readable clearer when using this module to
# access it's methods.
sub Readable
{
	my $self=shift;
	
	return ($self->{HANDLE}{READABLE});
}

# Makes my handle to AN::Tools::Storage clearer when using this module to
# access it's methods.
sub Storage
{
	my $self=shift;
	
	return ($self->{HANDLE}{STORAGE});
}

# Makes my handle to AN::Tools::String clearer when using this module to
# access it's methods.
sub String
{
	my $self=shift;
	
	return ($self->{HANDLE}{STRING});
}

# This sets and/or returns the address to be used when connecting to the DBus
sub dbus_address
{
	my $self=shift;
	my $set=shift if $_[0];
	
	# ie: unix:path=/tmp/tb_dbus.socket
	if ($set)
	{
		$self->{DBUS}{ADDRESS}=$set;
	}
	
	return ($self->{DBUS}{ADDRESS});
}

# Returns the handle to the DBus bus.
sub an_dbus_bus
{
	my $self=shift;
	return ($self->{DBUS}{BUS});
}

# Returns the handle to the DBus bus.
sub an_dbus_service
{
	my $self=shift;
	return ($self->{DBUS}{SERVICE});
}

# Returns the handle to the DBus bus.
sub an_dbus_object
{
	my $self=shift;
	return ($self->{DBUS}{OBJECT});
}

### Contributed by Shaun Fryer and Viktor Pavlenko by way of TPM.
# This is a helper to the above '_add_href' method. It is called each time a
# new string is to be created as a new hash key in the passed hash reference.
sub _add_hash_reference
{
	my $self=shift;
	my $href1=shift;
	my $href2=shift;
	
	for my $key (keys %$href2)
	{
		if (ref $href1->{$key} eq 'HASH')
		{
			$self->_add_hash_reference( $href1->{$key}, $href2->{$key} );
		}
		else
		{
			$href1->{$key} = $href2->{$key};
		}
	}
}

# This is called on startup to connect to the AN::Tools DBus server. If it's
# not yet running, this call should fire it up.
sub _connect_to_dbus
{
	my $self=shift;
	
	# Load Net::DBus if not yet loaded.
	$self->_load_net_dbus() if not $self->_net_dbus_loaded();
	my $bus="";
### Private bus isn't supported yet.
# 	if ($self->dbus_address)
# 	{
# 		# I've got an address, so use it.
# 		$bus=Net::DBus::Binding::Connection->new(address => $self->dbus_address);
# 	}
# 	else
# 	{
		# No address specified, connect to the system bus.
		print "Connecting to the DBus system bus.\n";
		$bus=Net::DBus->system();
		print "Connected: [$bus]\n";
# 	}
	
	print "Getting a handle on the service under the name space: [com.alteeve.Tools]\n";
	my $an_service=$bus->get_service("com.alteeve.Tools");
	print "Getting a handle on the object: [/com/alteeve/Tools] under the name space: [com.alteeve.Tools]\n";
	my $an_object=$an_service->get_object("/com/alteeve/Tools", "com.alteeve.Tools");
	
	print "Is the AN DBus server alive? [".$an_object->is_alive."].\n";
	
	print "Copying the bus, service and object into AN::Tool's bless'ed reference.\n";
	$self->{DBUS}{BUS}=$bus;
	$self->{DBUS}{SERVICE}=$an_service;
	$self->{DBUS}{OBJECT}=$an_object;
	
	return(1);
}

# This returns an array reference stored in 'self' that is used to hold an
# array of directories to search for.
sub _defaut_search_dirs
{
	my $self=shift;
	
	return ($self->{DEFAULT}{SEARCH_DIR});
}

# This sets or receives the underlying operating system's directory delimiter.
sub _directory_delimiter
{
	my ($self)=shift;
	
	# Pick up the passed in delimiter, if any.
	$self->{OS_VALUES}{DIRECTORY_DELIMITER}=shift if $_[0];
	
	return ($self->{OS_VALUES}{DIRECTORY_DELIMITER});
}

# When a method may possibly loop indefinately, it checks an internal counter
# against the value returned here and kills the program when reached.
sub _error_limit
{
	my $self=shift;
	
	return ($self->{ERROR_LIMIT});
}

# This simply sets and/or returns the internal variable that records when the
# Fcntl module has been loaded.
sub _fcntl_loaded
{
	my $self=shift;
	my $set=$_[0] ? shift : undef;
	
	$self->{LOADED}{Fcntl}=$set if defined $set;
	
	return ($self->{LOADED}{Fcntl});
}

# This is called when I need to parse a double-colon seperated string into two
# or more elements which represent keys in the 'conf' hash. Once suitably split
# up, the 'value' is read. For example, passing ('conf', 'foo::bar') will
# return the previously-set value 'baz'.
sub _get_hash_reference
{
	# 'href' is the hash reference I am working on.
	my $self=shift;
	my $param=shift;
	
	die "I didn't get a hash key string, so I can't pull hash reference pointer.\n" if ref($param->{key}) ne "HASH";
	die "The hash key string: [$param->{key}] doesn't seem to be valid. It should be a string in the format 'foo::bar::baz'.\n" if $param->{key} !~ /::/;
	
	# Split up the keys.
	my @keys=split /::/, $param->{key};
	my $last_key=pop @keys;
	
	# Re-order the array.
	my $_chref=$self->data;
	foreach my $key (@keys)
	{
		$_chref=$_chref->{$key};
	}
	
	return ($_chref->{$last_key});
}

# This simply sets and/or returns the internal variable that records when the
# IO::Handle module has been loaded.
sub _io_handle_loaded
{
	my $self=shift;
	my $set=$_[0] ? shift : undef;
	
	$self->{LOADED}{'IO::Handle'}=$set if defined $set;
	
	return ($self->{LOADED}{'IO::Handle'});
}

# This loads in 'Net::DBus::Exporter' on call.
# sub _load_net_dbus_exporter
sub _is_net_dbus_exporter_loadable
{
	my $self=shift;
	
	# As with 'Net::DBus::Object', loading 'Net::DBus::Exporter' here is
	# essentially useless. So instead, we test if it is loadable and return
	# '1' if so. It is up to the caller to load it with their interface
	# specified.
	eval 'use Net::DBus::Exporter qw(com.alteeve.Tools);';
	if ($@)
	{
		my $title="'AN::Tools' tried to load the 'Net::DBus::Exporter' module but it does not seem to be available.";
# 		$title="'AN::Tools' tried to load the 'Net::DBus::Exporter qw($service)' module but it does not seem to be available." if $service;
		my $message="Loading the perl module 'Net::DBus::Exporter' failed with the error: $@.";
# 		$message="Loading the perl module 'Net::DBus::Exporter qw($service)' failed with the error: $@.";
		$self->Alert->error({
			fatal	=>	1,
			title	=>	"$title",
			message	=>	"$message",
			code	=>	42,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		return (undef);
	}
	
	return (1);
}

# This loads in 'Net::DBus::Object' on call.
sub _is_net_dbus_object_loadable
{
	my $self=shift;
	
	# Normally, this needs to be called using 'use base ...', but that only
	# works in the calling package. So here, we simply check that it will
	# load at all and leave it to the caller to actually load it. For that
	# reason, this method returns '1' on success so that the caller can
	# use this in an 'if' statement a little more cleanly.
	eval 'use Net::DBus::Object;';
	if ($@)
	{
		$self->Alert->error({
			fatal	=>	1,
			title	=>	"'AN::Tools' tried to load the 'Net::DBus::Object' module but it does not seem to be available.",
			message	=>	"Loading the perl module 'Net::DBus::Object' failed with the error: $@.",
			code	=>	40,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		return (undef);
	}
	
	return (1);
}

# This loads in 'Fcntl's 'flock' functions on call.
sub _load_fcntl
{
	my $self=shift;
	
	print "'eval'ing Fcntl\n";
	eval 'use Fcntl \':flock\';';
# 	eval 'use Fcntl;';
	if ($@)
	{
		$self->Alert->error({
			fatal	=>	1,
			title	=>	"'AN::Tools' tried to load the 'fcntl' module but it does not seem to be available.",
			message	=>	"Loading the perl module 'Fcntl' failed with the error: [$@].",
			code	=>	31,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		return (undef);
	}
	else
	{
		# Good, record it as loaded.
		$self->_fcntl_loaded(1);
	}
	
	return (0);
}

# This loads the 'Math::BigInt' module.
sub _load_io_handle
{
	my $self=shift;
	
	eval 'use IO::Handle;';
	if ($@)
	{
		$self->Alert->error({
			fatal	=>	1,
			title	=>	"'AN::Tools' tried to load the 'IO::Handle' module but it does not seem to be available.",
			message	=>	"Loading the perl module 'IO::Handle' failed with the error: [$@].",
			code	=>	13,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}
	else
	{
		# Good, record it as loaded.
		$self->_io_handle_loaded(1);
	}
	
	return(0);
}

# This loads the 'Math::BigInt' module.
sub _load_math_bigint
{
	my $self=shift;
	
	eval 'use Math::BigInt;';
	if ($@)
	{
		$self->Alert->error({
			fatal	=>	1,
			title	=>	"'AN::Tools' tried to load the 'Math::BigInt' module but it does not seem to be available.",
			message	=>	"Loading the perl module 'Math::BigInt' failed with the error: [$@].",
			code	=>	9,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}
	else
	{
		# Good, record it as loaded.
		$self->_math_bigint_loaded(1);
	}
	
	return(0);
}

# This loads in 'Net::DBus' on call.
sub _load_net_dbus
{
	my $self=shift;
	
	eval 'use Net::DBus;';
	if ($@)
	{
		$self->Alert->error({
			fatal	=>	1,
			title	=>	"'AN::Tools' tried to load the 'Net::DBus' module but it does not seem to be available.",
			message	=>	"Loading the perl module 'Net::DBus' failed with the error: $@.",
			code	=>	36,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		return (undef);
	}
	else
	{
		# Good, record it as loaded.
		$self->_net_dbus_loaded(1);
		print "Net::DBus loaded.\n";
	}
	
	return (0);
}

# This loads in 'Net::DBus::Reactor' on call.
sub _load_net_dbus_reactor
{
	my $self=shift;
	
	eval 'use Net::DBus::Reactor;';
	if ($@)
	{
		$self->Alert->error({
			fatal	=>	1,
			title	=>	"'AN::Tools' tried to load the 'Net::DBus::Reactor' module but it does not seem to be available.",
			message	=>	"Loading the perl module 'Net::DBus::Reactor' failed with the error: $@.",
			code	=>	38,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		return (undef);
	}
	else
	{
		# Good, record it as loaded.
		$self->_net_dbus_reactor_loaded(1);
		print "Net::DBus::Reactor loaded.\n";
	}
	
	return (0);
}

# This loads in 'Net::DBus::RemoteObject' on call.
sub _load_net_dbus_remoteobject
{
	my $self=shift;
	
	eval 'use Net::DBus::RemoteObject;';
	if ($@)
	{
		$self->Alert->error({
			fatal	=>	1,
			title	=>	"'AN::Tools' tried to load the 'Net::DBus::RemoteObject' module but it does not seem to be available.",
			message	=>	"Loading the perl module 'Net::DBus::RemoteObject' failed with the error: $@.",
			code	=>	41,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		return (undef);
	}
	else
	{
		# Good, record it as loaded.
		$self->_net_dbus_remoteobject_loaded(1);
		print "Net::DBus::RemoteObject loaded.\n";
	}
	
	return (0);
}

# This loads in 'Net::DBus::RemoteService' on call.
sub _load_net_dbus_remoteservice
{
	my $self=shift;
	
	eval 'use Net::DBus::RemoteService;';
	if ($@)
	{
		$self->Alert->error({
			fatal	=>	1,
			title	=>	"'AN::Tools' tried to load the 'Net::DBus::RemoteService' module but it does not seem to be available.",
			message	=>	"Loading the perl module 'Net::DBus::RemoteService' failed with the error: $@.",
			code	=>	39,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		return (undef);
	}
	else
	{
		# Good, record it as loaded.
		$self->_net_dbus_remoteservice_loaded(1);
		print "Net::DBus::RemoteService loaded.\n";
	}
	
	return (0);
}

# This loads in 'Net::DBus::Service' on call.
sub _load_net_dbus_service
{
	my $self=shift;
	
	eval 'use Net::DBus::Service;';
	if ($@)
	{
		$self->Alert->error({
			fatal	=>	1,
			title	=>	"'AN::Tools' tried to load the 'Net::DBus::Service' module but it does not seem to be available.",
			message	=>	"Loading the perl module 'Net::DBus::Service' failed with the error: $@.",
			code	=>	37,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		return (undef);
	}
	else
	{
		# Good, record it as loaded.
		$self->_net_dbus_service_loaded(1);
		print "Net::DBus::Service loaded.\n";
	}
	
	return (0);
}

### Contributed by Shaun Fryer and Viktor Pavlenko by way of TPM.
# This takes a string with double-colon seperators and divides on those
# double-colons to create a hash reference where each element is a hash key.
sub _make_hash_reference
{
	my $self=shift;
	my $href=shift;
	my $key_string=shift;
	my $value=shift;
	
	if ($self->{CHOMP_ROOT}) { $key_string=~s/\w+:://; }
	
	my @keys = split /::/, $key_string;
	my $last_key = pop @keys;
	my $_href = {};
	$_href->{$last_key}=$value;
	while (my $key = pop @keys)
	{
		my $elem = {};
		$elem->{$key} = $_href;
		$_href = $elem;
	}
	$self->_add_hash_reference($href, $_href);
}

# This simply sets and/or returns the internal variable that records when the
# Math::BigInt module has been loaded.
sub _math_bigint_loaded
{
	my $self=shift;
	my $set=$_[0] ? shift : undef;
	
	$self->{LOADED}{'Math::BigInt'}=$set if defined $set;
	
	return ($self->{LOADED}{'Math::BigInt'});
}

# This simply sets and/or returns the internal variable that records when the
# Net::DBus::Exporter module has been loaded.
sub _net_dbus_exporter_loaded
{
	my $self=shift;
	my $set=$_[0] ? shift : undef;
	
	$self->{LOADED}{'Net::DBus::Exporter'}=$set if defined $set;
	
	return ($self->{LOADED}{'Net::DBus::Exporter'});
}

# This simply sets and/or returns the internal variable that records when the
# Net::Dbus module has been loaded.
sub _net_dbus_loaded
{
	my $self=shift;
	my $set=$_[0] ? shift : undef;
	
	$self->{LOADED}{'Net::DBus'}=$set if defined $set;
	
	return ($self->{LOADED}{'Net::DBus'});
}

# This simply sets and/or returns the internal variable that records when the
# Net::DBus::Object module has been loaded.
sub _net_dbus_object_loaded
{
	my $self=shift;
	my $set=$_[0] ? shift : undef;
	
	$self->{LOADED}{'Net::DBus::Object'}=$set if defined $set;
	
	return ($self->{LOADED}{'Net::DBus::Object'});
}

# This simply sets and/or returns the internal variable that records when the
# Net::DBus::Reactor module has been loaded.
sub _net_dbus_reactor_loaded
{
	my $self=shift;
	my $set=$_[0] ? shift : undef;
	
	$self->{LOADED}{'Net::DBus::Reactor'}=$set if defined $set;
	
	return ($self->{LOADED}{'Net::DBus::Reactor'});
}

# This simply sets and/or returns the internal variable that records when the
# Net::DBus::RemoteObject module has been loaded.
sub _net_dbus_remoteobject_loaded
{
	my $self=shift;
	my $set=$_[0] ? shift : undef;
	
	$self->{LOADED}{'Net::DBus::RemoteObject'}=$set if defined $set;
	
	return ($self->{LOADED}{'Net::DBus::RemoteObject'});
}

# This simply sets and/or returns the internal variable that records when the
# Net::DBus::RemoteService module has been loaded.
sub _net_dbus_remoteservice_loaded
{
	my $self=shift;
	my $set=$_[0] ? shift : undef;
	
	$self->{LOADED}{'Net::DBus::RemoteService'}=$set if defined $set;
	
	return ($self->{LOADED}{'Net::DBus::RemoteService'});
}

# This simply sets and/or returns the internal variable that records when the
# Net::DBus::Service module has been loaded.
sub _net_dbus_service_loaded
{
	my $self=shift;
	my $set=$_[0] ? shift : undef;
	
	$self->{LOADED}{'Net::DBus::Service'}=$set if defined $set;
	
	return ($self->{LOADED}{'Net::DBus::Service'});
}

1;
