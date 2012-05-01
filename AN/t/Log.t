#!/usr/bin/perl -Tw
#
# This is the test script for the AN::Tools family of modules.
# 

use AN::Tools 0.0.001;
my $an=AN::Tools->new();

# Make sure that $parent matches $an.
my $parent=$an->Log->parent();
is($an, $parent, "Internal 'parent' method returns same blessed reference as is in \$an.");

# Make sure that all methods are available.
my @methods=(
	"parent", 
	"entry", 
	"level", 
	"short_timestamp", 
	"archives", 
	"cycle_size", 
	"compression", 
	"compression_switches", 
	"compression_suffix", 
	"file", 
	"check", 
	"_cycle", 
	"get_handle", 
	"chomp_head", 
	"chomp_head_buffer"
);
can_ok("AN::Tools::Log", @methods);

