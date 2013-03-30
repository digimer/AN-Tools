package AN::Tools::String;

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "String.pm";


sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Storage->new()\n";
	my $class = shift;
	
	my $self  = {
		CORE_WORDS	=>	"AN::tools.xml",
		FORCE_UTF8	=>	0,
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

# This forces UTF8 mode when reading a words file. This should not be used
# normally as the words file should already be UTF8 encoded.
sub force_utf8
{
	my $self = shift;
	my $set  = defined $_[0] ? shift : undef;
	
	if (defined $set)
	{
		if (($set == 0) || ($set == 1))
		{
			$self->{FORCE_UTF8} = $set;
		}
		else
		{
			my $an = $self->parent;
			$an->Alert->error({
				fatal	=>	1,
				title	=>	"Invalid argument",
				message	=>	"The invalid argument: [$set] was passed into the 'AN::Tools::String->force_utf8()'. Only 1 or 0 are valid arguments.",
				code	=>	14,
				file	=>	"$THIS_FILE",
				line	=>	__LINE__
			});
		}
	}
	
	return ($self->{FORCE_UTF8});
}

# This takes a word key and, optionally, a hash reference, a language and/or an
# variables array reference. It returns the corresponding string from the hash
# reference data containing the data from a 'read_words()' call.
sub get
{
	my $self  = shift;
	my $param = shift;
	
	# This just makes the code more consistent.
	my $an    = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	my $key;
	my $hash  = $an->data;
	#print "$THIS_FILE ".__LINE__."; hash: [$hash]\n";
	
	my $vars;
	my $lang  = $an->default_language;
	#print "$THIS_FILE ".__LINE__."; lang: [$lang]\n";
	
	# Catch infinite loops
	my $i     = 0;
	my $limit = $an->_error_limit;
	#print "$THIS_FILE ".__LINE__."; limit: [$limit]\n";
	
	# Now see if the user passed the values in a hash reference or
	# directly.
	#print "$THIS_FILE ".__LINE__."; param: [$param]\n";
	if (ref($param) eq "HASH")
	{
		# Values passed in a hash, good.
		$key  = $param->{key}      if $param->{key};
		$vars = $param->{variable} ? $param->{variable} : "";
		$lang = $param->{language} if $param->{language};
		$hash = $param->{hash}     if $param->{hash};
		#print "$THIS_FILE ".__LINE__."; key: [$key], vars: [$vars], lang: [$lang], hash: [$hash]\n";
	}
	else
	{
		# Values passed directly.
		$key  = $param;
		$vars = $_[0] if defined $_[0];
		$lang = $_[1] if defined $_[1];
		$hash = $_[2] if defined $_[2];
		#print "$THIS_FILE ".__LINE__."; key: [$key], vars: [$vars], lang: [$lang], hash: [$hash]\n";
	}
	
	# Make sure that 'hash' is a hash reference
	#print "$THIS_FILE ".__LINE__."; hash: [$hash]\n";
	if (ref($hash) ne "HASH")
	{
		#print "$THIS_FILE ".__LINE__."; The 'hash' string does not contain a hash.\n";
		$an->Alert->error({
			fatal	=>	1,
			title	=>	"Invalid Argument",
			message	=>	"The 'AN::Tools::String' module's 'get' method was passed an invalid 'hash' argument: [$hash]. This must be a hash reference containing data read in from an XML words file by the 'read_words()' method.",
			code	=>	15,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}

	# Make sure that 'vars' is an array reference, if set.
	#print "$THIS_FILE ".__LINE__."; vars: [$vars]\n";
	if (($vars) && (ref($vars) ne "ARRAY"))
	{
		#print "$THIS_FILE ".__LINE__."; The 'vars' string has the value: [$vars], which is not an array, as was expected.\n";
		$an->Alert->error({
			fatal	=>	1,
			title	=>	"Invalid Argument",
			message	=>	"The 'AN::Tools::String' module's 'get' method was passed an invalid 'variable' argument: [$vars]. This must be an array reference containing elements intended to replace corresponding #!var!x!# replacement keys in the requested string.",
			code	=>	16,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		return (undef);
	}
	
	# Make sure that the request language exists in the hash.
	if (ref($hash->{words}{lang}{$lang}) ne "HASH")
	{
		# If not, I have to just 'die' because calling Alert->error()
		# would trigger an infite loop.
		print "$THIS_FILE ".__LINE__."; [ ERROR ] Invalid Language!<br />\n";
		print "$THIS_FILE ".__LINE__."; [ ERROR ] The 'AN::Tools::String' module's 'get' method was passed an invalid 'language' argument: [$lang]. This must match one of the languages in the words file's <langs>...</langs> block.<br />\n",
		print "$THIS_FILE ".__LINE__."; [ ERROR ] Exiting in file: [$THIS_FILE] at line: [".__LINE__."]<br />\n";
		use Data::Dumper;
		print "<pre>\n";
		print Dumper $hash, "\n";
		print "</pre>\n";
		exit(17);
	}
	
	# Make sure that the request key is in the language hash.
	if (not exists $hash->{words}{lang}{$lang}{key}{$key}{content})
	{
		#print "$THIS_FILE ".__LINE__."; no string key.\n";
		$an->Alert->error({
			fatal	=>	1,
			title	=>	"Invalid String Key",
			message	=>	"The 'AN::Tools::String' module's 'get' method was passed the 'key' argument: [$key] which was not found in the language: [$lang]. This key must be defined in one of the read in words files.\n",
			code	=>	18,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		return (undef);
	}
	
	# Now pick out my actual string.
	my $string =  $hash->{words}{lang}{$lang}{key}{$key}{content};
	$string    =~ s/^\n//;
	
	# This clears off the new-line and trailing white-spaces caused by the
	# indenting of the '</key>' field in the words XML file when printing
	# to the command line.
	$string =~ s/\n(\s+)$//;
	
	# Make sure that if the string has '#!var!x!#', that 'vars' is an array
	# reference. If it isn't, it would trigger an infinite loop later.
	if (($string =~ /#!var!\d+!#/) && (ref($vars) ne "ARRAY"))
	{
		$an->Alert->error({
			fatal	=>	1,
			title	=>	"Missing Variables",
			message	=>	"The 'AN::Tools::String' module's 'get()' was passed a string with a '#!var!x!#' replacement key without an array reference containing the replacement keys. This would trigger an infinite loop and is thus a fatal error.\n",
			code	=>	36,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		return (undef);
	}
	
	# Substitute in any variables if needed.
	#print "$THIS_FILE ".__LINE__."; vars: [".ref($vars)."]\n" if $vars;
	if (ref($vars) eq "ARRAY")
	{
		#foreach my $val (@{$vars}) { print "$THIS_FILE ".__LINE__."; val: [$val]\n"; }
		$string = $an->String->_insert_vars({
			  string	=>	$string,
			  variable	=>	$vars,
		});
	}
	
	# Process the just-read string.
	$string = $an->String->_process({
		  string	=>	$string,
		  language	=>	$lang,
		  hash		=>	$hash,
	});
	
	return ($string);
}

# This takes the path/name of an XML file containing AN::Tools type words and
# reads them into a hash reference.
sub read_words
{
	my $self  = shift;
	my $param = $_[0] ? shift : "";
	
	# This just makes the code more consistent.
	my $an    = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# Setup my variables.
	my $file = $self->{CORE_WORDS};
	my $hash = $an->data;
	
	# Now see if the user passed the values in a hash reference or
	# directly.
	if (ref($param) eq "HASH")
	{
		# Values passed in a hash, good.
		$file = $param->{file} if $param->{file};
		$hash = $param->{hash} if ref($param->{hash}) eq "HASH";
	}
	else
	{
		# Values passed directly.
		$file = $param;
		$hash = shift if ((defined $_[0]) && (ref($_[0]) eq "HASH"));
	}
	
	# This falls back to the CORE_WORDS if the user passed an empty file.
	$file = $an->Storage->find({
		file		=>	"$self->{CORE_WORDS}",
		fatal		=>	1,
	}) if not $file;
	
	# Make sure that the 'file' exists and is readable.
	#print "$THIS_FILE ".__LINE__."; words file: [$file]\n";
	if (not -e $file)
	{
		$an->Alert->error({
			fatal	=>	1,
			title	=>	"Unable to find the words file.'",
			message	=>	"The words file: [$file] could not be found. Please check that it exists.",
			code	=>	11,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}
	if (not -r $file)
	{
		$an->Alert->error({
			fatal	=>	1,
			title	=>	"Unable to read the words file.'",
			message	=>	"The words file: [$file] was found but could not be read. Please check that it exists.",
			code	=>	12,
			file	=>	"$THIS_FILE",
			line	=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}
	
	my $in_comment  = 0;	# Set to '1' when in a comment stanza that spans more than one line.
	my $in_data     = 0;	# Set to '1' when reading data that spans more than one line.
	my $closing_key = "";	# While in_data, look for this key to know when we're done.
	my $xml_version = "";	# The XML version of the words file.
	my $encoding    = "";	# The encoding used in the words file. Should only be UTF-8.
	my $data        = "";	# The data being read for the given key.
	my $key_name    = "";	# This is a double-colon list of hash keys used to build each hash element.
	
	# Load IO::Handle if needed.
	$an->_load_io_handle() if not $an->_io_handle_loaded();
	
	# Read in the XML file with the word strings to load.
	my $read       = IO::Handle->new;
	my $shell_call = "<$file";
	open ($read, $shell_call) || $an->Alert->error({
		fatal	=>	1,
		title	=>	"'AN::Tools::String->read()' was not able to open the words file for reading.",
		message	=>	"The AN::Tools::String methid 'read' was not able to open the words file: [$file]. The error was: $!",
		code	=>	28,
		file	=>	"$THIS_FILE",
		line	=>	__LINE__
	});
	
	# If I have been asked to read in UTF-8 mode, do so.
	if ($an->String->force_utf8)
	{
		binmode $read, "encoding(utf8)";
	}
	
	# Now loop through the XML file, line by line.
	while (<$read>)
	{
		chomp;
		my $line = $_;
		
		### Deal with comments.
		# Look for a clozing stanza if I am (still) in a comment.
		if (($in_comment) && ( $line =~ /-->/ ))
		{
			$line       =~ s/^(.*?)-->//;
			$in_comment =  0;
		}
		next if ($in_comment);
		
		# Strip out in-line comments.
		while ( $line =~ /<!--(.*?)-->/ )
		{
			$line =~ s/<!--(.*?)-->//;
		}
		
		# See if there is an comment opening stanza.
		if ( $line =~ /<!--/ )
		{
			$in_comment =  1;
			$line       =~ s/<!--(.*)$//;
		}
		### Comments dealt with.
		
		### Parse data
		# XML data
		if ($line =~ /<\?xml version="(.*?)" encoding="(.*?)"\?>/)
		{
			$xml_version = $1;
			$encoding    = $2;
			next;
		}
		
		# If I am not "in_data" (looking for more data for a currently in use key).
		if (not $in_data)
		{
			# Skip blank lines.
			next if $line =~ /^\s+$/;
			next if $line eq "";
			$line =~ s/^\s+//;
			
			# Look for an inline data-structure.
			if (($line =~ /<(.*?) (.*?)>/) && ($line =~ /<\/$1>/))
			{
				# First, look for CDATA.
				my $cdata = "";
				if ($line =~ /<!\[CDATA\[(.*?)\]\]>/)
				{
					$cdata =  $1;
					$line  =~ s/<!\[CDATA\[$cdata\]\]>/$cdata/;
				}
				
				# Pull out the key and name.
				my $key  =  $line;
				my $name =  $line;
				my $data =  $line;
				$key     =~ s/^<(\w+).*/$1/;
				$name    =~ s/^<$key name="(\w+).*/$1/;
				$data    =~ s/^<$key name="$name">(.*?)<\/$key>(.*)/$1/;
				
				# If I picked up data within a CDATA block,
				# push it into 'data' proper.
				$data = $cdata if $cdata;
				
				# No break out the data and push it into the
				# corresponding keyed hash reference '$hash'.
				$an->_make_hash_reference($hash, "${key_name}::${key}::${name}::content", $data);
				
				next;
			}
			
			# Look for a self-contained unkeyed structure.
			if (($line =~ /<(.*?)>/) && ($line =~ /<\/$1>/))
			{
				my $key =  $line;
				$key    =~ s/<(.*?)>.*/$1/;
				$data   =  $line;
				$data   =~ s/<$key>(.*?)<\/$key>/$1/;
				$an->_make_hash_reference($hash, "${key_name}::${key}", $data);
				next;
			}
			
			# Look for a line with a closing stanza.
			if ($line =~ /<\/(.*?)>/)
			{
				my $closing_key =  $line;
				$closing_key    =~ s/<\/(\w+)>/$1/;
				$key_name       =~ s/(.*?)::$closing_key(.*)/$1/;
				next;
			}
			
			# Look for a key with an embedded value.
			if ($line =~ /^<(\w+) name="(.*?)" (\w+)="(.*?)">/)
			{
				my $key   =  $1;
				my $name  =  $2;
				my $key2  =  $3;
				my $data  =  $4;
				$key_name .= "::${key}::${name}";
				$an->_make_hash_reference($hash, "${key_name}::${key}::${key2}", $data);
				next;
			}
			
			# Look for a contained value.
			if ($line =~ /^<(\w+) name="(.*?)">(.*)/)
			{
				my $key  = $1;
				my $name = $2;
				# Don't scope 'data' locally in case it spans
				# multiple lines.
				$data    = $3;
				
				# Parse the data now.
				if ($data =~ /<\/$key>/)
				{
					# Fully contained data.
					$data =~ s/<\/$key>(.*)$//;
					$an->_make_hash_reference($hash, "${key_name}::${key}::${name}", $data);
				}
				else
				{
					# Element closes later.
					$in_data     =  1;
					$closing_key =  $key;
					$name        =~ s/^<$key name="(\w+).*/$1/;
					$key_name    .= "::${key}::${name}";
					$data        =~ s/^<$key name="$name">(.*)/$1/;
					$data        .= "\n";
				}
				next;
			}
			
			# Look for an opening data structure.
			if ($line =~ /<(.*?)>/)
			{
				my $key   =  $1;
				$key_name .= "::$key";
				next;
			}
		}
		else
		{
			### I'm in a multi-line data block.
			# If this line doesn't close the data block, feed it
			# wholesale into 'data'. If it does, see how much of
			# this line, if anything, is pushed into 'data'.
			if ($line !~ /<\/$closing_key>/)
			{
				$data .= "$line\n";
			}
			else
			{
				# This line closes the data block.
				$in_data =  0;
				$line    =~ s/(.*?)<\/$closing_key>/$1/;
				$data    .= "$line";
				
				# If this line contain new-line control
				# characters, break the line up into multiple
				# lines and process them seperately.
				my $save_data = "";
				my @lines     = split/\n/, $data;
				
				# I use this to track CDATA blocks.
				my $in_cdata  = 0;
				
				# Loop time.
				foreach my $line (@lines)
				{
					# If I am in a CDATA block, check for
					# the closing stanza.
					if (($in_cdata == 1) && ($line =~ /]]>$/))
					{
						# CDATA closes here.
						$line      =~ s/]]>$//;
						$save_data .= "\n$line";
						$in_cdata  =  0;
					}
					
					# If this line is a self-contained
					# CDATA block, pull the data out.
					# Otherwise, check if this line starts
					# a CDATA block.
					if (($line =~ /^<\!\[CDATA\[/) && ($line =~ /]]>$/))
					{
						# CDATA opens and closes in this line.
						$line      =~ s/^<\!\[CDATA\[//;
						$line      =~ s/]]>$//;
						$save_data .= "\n$line";
					}
					elsif ($line =~ /^<\!\[CDATA\[/)
					{
						$line     =~ s/^<\!\[CDATA\[//;
						$in_cdata =  1;
					}
					
					# If I am in a CDATA block, feed the
					# (sub)line into 'save_data' wholesale.
					if ($in_cdata == 1)
					{
						# Don't analyze, just store.
						$save_data .= "\n$line";
					}
					else
					{
						# Not in CDATA, look for XML data.
						while (($line =~ /<(.*?)>/) && ($line =~ /<\/$1>/))
						{
							# Found a value.
							my $key =  $line;
							$key    =~ s/.*?<(.*?)>.*/$1/;
							$data   =  $line;
							$data   =~ s/.*?<$key>(.*?)<\/$key>/$1/;
							
							$an->_make_hash_reference($hash, "${key_name}::${key}", $data);
							$line =~ s/<$key>(.*?)<\/$key>//
						}
						$save_data .= "\n$line";
					}
				}
				
				# Knock out and new-lines and save.
				$save_data=~s/^\n//;
				if ($save_data =~ /\S/s)
				{
					# Record the data in my '$hash' hash
					# reference.
					$an->_make_hash_reference($hash, "${key_name}::content", $save_data);
				}
				
				$key_name =~ s/(.*?)::$closing_key(.*)/$1/;
			}
		}
		next if $line eq "";
	}
	$read->close();
	
	# Set a couple values about this file.
	$self->{FILE}->{XML_VERSION} = $xml_version;
	$self->{FILE}->{ENCODING}    = $encoding;
	
	# Return the number.
	return (1);
}

# This takes a string and substitutes out the various replacement keys as
# needed until the string is ready for display. The only thing it doesn't
# handle is substituting '#!var!x!#' keys into a string. For that, call the
# 'get' method with it's given variable array reference and store the
# results in a string. This is requried because there is currently no way for
# any of the called methods within here to know which string the variables in
# the array reference belong in.
sub _process
{
	my $self  = shift;
	my $param = shift;
	
	my $an    = $self->parent;
	
	# Start looping through the passed string until all the replacement
	# keys are gone.
	my $i     = 0;
	my $limit = $an->_error_limit;
	$limit    = 6;
# 	print "Error limit: [$limit]\n";
# 	print "$i: $param->{string}\n";
	while ($param->{string} =~ /#!(.+?)!#/)
	{
		# Substitute 'word' keys, but without 'vars'. This has to be
		# first! 'protect' will catch 'word' keys, because no where
		# else are they allowed.
		#print __LINE__."; string: [$param->{string}]\n";
		#print __LINE__."; language: [$param->{language}]\n";
		#print __LINE__."; hash: [$param->{hash}]\n";
		$param->{string} = $an->String->_insert_word({
			  string	=>	$param->{string},
			  language	=>	$param->{language},
			  hash		=>	$param->{hash},
		});
		
		# Protect unmatchable keys.
		$param->{string} = $an->String->_protect({
			string		=>	$param->{string},
		});
		
		# Inject any 'data' values.
		$param->{string} = $an->String->_insert_data({
			string	=>	$param->{string},
		});
		
		die "Infinite loop detected while processing the string: [$param->{string}], exiting.\n" if $i > $limit;
		$i++;
	}
	
	# Restore and unrecognized substitution values.
	$param->{string} = $an->String->_restore_protected({
		string		=>	$param->{string},
	});
	
	# Do any output mode specific formatting.
	$param->{string} = $an->String->_format_mode({
		string		=>	$param->{string},
	});
	
	return ($param->{string});
}

# Do any output mode specific formatting.
sub _format_mode
{
	my $self  = shift;
	my $param = shift;
	
	my $an    = $self->parent;
	
	# I don't think I need this now as I only wrap the string after it's
	# been processed by 'print_template'. It may have future use though.
	return ($param->{string});
}

# This restores the original key format for keys that were protected by the
# '_protect' method.
sub _restore_protected
{
	my $self  = shift;
	my $param = shift;
	
	my $an    = $self->parent;
	
	# Restore and unrecognized substitution values.
	my $i = 0;
	while ($param->{string} =~ /!#(.+?)#!/)
	{
		my $check        =  $1;
		$param->{string} =~ s/!#$check#!/#!$check!#/g;
		
		die "Infinite loop detected while restoring protected replacement keys in the string: [$param->{string}], exiting.\n" if $i > $an->_error_limit;
		$i++;
	}
	
	return ($param->{string});
}

# This does the actual work of substituting 'data' keys.
sub _insert_data
{
	my $self  = shift;
	my $param = shift;
	
	my $an    = $self->parent;
	
	my $i = 0;
	while ($param->{string} =~ /#!data!(.+?)!#/)
	{
		my $id = $1;
		if ($id =~ /::/)
		{
			# Multi-dimensional hash.
			my $value = $an->_get_hash_reference({
				key	=>	$id,
			});
			if (not defined $value)
			{
				$param->{string} =~ s/#!data!$id!#/!!a[$id]!!/;
			}
			else
			{
				$param->{string} =~ s/#!data!$id!#/$value/;
			}
		}
		else
		{
			# One dimension
			if (not defined $an->data->{$id})
			{
				$param->{string} =~ s/#!data!$id!#/!!b[$id]!!/;
			}
			else
			{
				my $val          =  $an->data->{$id};
				$param->{string} =~ s/#!data!$id!#/$val/;
			}
		}
		
		die "Infinite loop detected while replacing data keys in the string: [$param->{string}], exiting.\n" if $i > $an->_error_limit;
		$i++;
	}
	
	return ($param->{string});
}

# Protect unrecognized or unused replacement keys. I do this to protect strings
# possibly set or created by a user.
sub _protect
{
	my $self  = shift;
	my $param = shift;
	my $an    = $self->parent;
	my $i     = 0;
	foreach my $check ($param->{string} =~ /#!(.+?)!#/)
	{
		if (($check !~ /^free/) &&
		    ($check !~ /^replace/) &&
		    ($check !~ /^data/) &&
		    ($check !~ /^word/) &&
		    ($check !~ /^var/))
		{
			# Simply invert the '#!...!#' to '!#...#!'.
			$param->{string} =~ s/#!($check)!#/!#$1#!/g;
		}
		
		die "Infinite loop detected while protecting replacement keys in the string: [$param->{string}], exiting.\n" if $i > $an->_error_limit;
		$i++;
	}
	
	return ($param->{string});
}

# This is called to process '#!word!...!#' keys in string. It DOES NOT
# support substituting '#!var!x!#' keys found in imported word strings! This
# is meant to insert simple word strings into template files.
sub _insert_word
{
	my $self  = shift;
	my $param = shift;
	
	my $an    = $self->parent;
	
	# Loop through the string until all '#!word!...!#' keys are gone.
	my $i     = 0;
	while ($param->{string} =~ /#!word!(.+?)!#/)
	{
		my $key      = $1;
		my $say_word = $an->String->get({
			  key		=>	$key,
			  language	=>	$param->{language},
			  hash		=>	$param->{hash},
			  variable	=>	undef,
		});
		if ($say_word)
		{
			$param->{string} =~ s/#!word!$key!#/$say_word/;
		}
		else
		{
			$param->{string} =~ s/#!word!$key!#/!!e[$key]!!/;
		}
		
		die "Infinite loop detected while replacing #!word!...!# keys in the string: [$param->{string}], exiting.\n" if $i > $an->_error_limit;
		$i++;
	}
	return ($param->{string});
}

# This takes a string with '#!var!x!#' keys, where 'x' is an integer matching
# an entry in the passed array reference and uses the data from the array to
# replace the matching '#!var!x!#' entry.
sub _insert_vars
{
	my $self  = shift;
	my $param = shift;
	my $an    = $self->parent;
	my $i     = 0;
	while ($param->{string} =~ /#!var!(.+?)!#/)
	{
		my $val = $param->{variable}->[$1];
# 		print "$THIS_FILE ".__LINE__."; val: [$val]\n";
		if (not defined $param->{variable}->[$1])
		{
			# I can't expect there to always be a defined value in
			# the @vals array at any given position so if it's
			# blank I blank the key.
			$param->{string} =~ s/#!var!$1!#//;
		}
		else
		{
			chomp $val;
			$param->{string} =~ s/#!var!$1!#/$val/;
		}
		die "Infinite loop detected while injecting variables into the string: [$param->{string}], exiting.\n" if $i > $an->_error_limit;
		$i++;
	}
	
	return ($param->{string});
}

1;
