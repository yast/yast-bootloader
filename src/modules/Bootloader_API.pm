#!/usr/bin/perl -w

#
# Interface to perl-Bootloader library
#

package Bootloader_API;

use strict;

use Bootloader::Library;
use LIMAL::LogHelper;

our %TYPEINFO;

BEGIN { $TYPEINFO{ALL_METHODS} = 0; }

# create a new bootloader object
my $lib_ref = Bootloader::Library->new();

my @lines_cache = ();
my $lines_cache_index = 0;

# Log collected log messages
sub DumpLog {
    foreach my $rec (@{$lib_ref->GetLogRecords() || []})
    {
	if ($rec->{"level"} eq "debug")
	{
	    LIMAL::LogHelper::logDebug ($rec->{"message"});
	}
	elsif ($rec->{"level"} eq "milestone")
	{
	    LIMAL::LogHelper::logInfo ($rec->{"message"});
	}
	elsif ($rec->{"level"} eq "warning")
	{
	    LIMAL::LogHelper::logError ("WARNING: " . $rec->{"message"});
	}
	elsif ($rec->{"level"} eq "error")
	{
	    LIMAL::LogHelper::logError ($rec->{"message"});
	}
	else
	{
	    LIMAL::LogHelper::logError ("Incomplete log record");
	    LIMAL::LogHelper::logError ($rec->{"message"});
	}
    }
}


BEGIN { $TYPEINFO{setLoaderType} = ["function", "void", "string"]; }
# do library initialization for a specific bootloader type
sub setLoaderType($) {
    my ($lt) = @_;
    my $ret = $lib_ref->SetLoaderType($lt);

    @lines_cache = ();
    $lines_cache_index = 0;
    DumpLog();
    return $ret;
}

BEGIN { $TYPEINFO{updateBootloader} = ["function", "boolean", "boolean"]; }
sub updateBootloader() {
    my ($avoid_init) = @_;
    my $ret = $lib_ref->UpdateBootloader($avoid_init);

    DumpLog();
    return $ret;
}

BEGIN { $TYPEINFO{updateSerialConsole} = ["function", "string", "string", "string"]; }
sub updateSerialConsole() {
    my ($my_append, $my_console) = @_;
    my $ret = $lib_ref->UpdateSerialConsole($my_append, $my_console);

    DumpLog();
    return $ret;
}

BEGIN { $TYPEINFO{initializeBootloader} = ["function", "boolean"]; }
# first time initialization of firmware/bios specific code
sub initializeBootloader() {
    my $ret = $lib_ref->InitializeBootloader();

    DumpLog();
    return $ret;
}

BEGIN { $TYPEINFO{readSettings} = ["function", "boolean", "boolean"]; }
# read configuration
sub readSettings() {
    my ($avoid_reading_device_map) = @_;
    my $ret = $lib_ref->ReadSettings($avoid_reading_device_map);

    DumpLog();
    return $ret ? "true" : "false";
}

BEGIN { $TYPEINFO{writeSettings} = ["function", "boolean"]; }
# write settings to the files
sub writeSettings() {
    my $ret = $lib_ref->WriteSettings();
    DumpLog();

    return $ret;
}


BEGIN { $TYPEINFO{getMetaData} = ["function", ["map", "string", "string"]]; }
# get data format and type description as far as available for
# specific bootloader
sub getMetaData() {
    my $mdat_ref = $lib_ref->GetMetaData() || {};

    # copy the hash and encode meta tags
    my %metadata=();
    while ((my $key, my $value) = each ( %{$mdat_ref} )) {
	if (ref($value)) {
	    if  (ref($value) eq "HASH") {
		foreach my $k (keys %$value) {
		    $metadata{"%" . $key . "%" . $k} = $value->{$k};
		}
	    }
	    elsif  (ref($value) eq "ARRAY") {
                   foreach my $i (0 .. $#$value) {
		       $metadata{"#" . $key . "#" . $i} = $value->[$i];
                   }
	       }
	}
	else {
	    $metadata{$key} = $value;
	}
    }
 
    DumpLog();
    return \%metadata;
}


BEGIN { $TYPEINFO{getDeviceMapping} = ["function", ["map", "string", "string"]]; }
sub getDeviceMapping() {
    my $devmap = $lib_ref->GetDeviceMapping () || {};
    DumpLog();
    return $devmap;
}

BEGIN { $TYPEINFO{setDeviceMapping} = ["function", "boolean", ["map", "string", "string"]]; }
sub setDeviceMapping($) {
    my ($dm) = @_;

    my $ret = $lib_ref->SetDeviceMapping ($dm);
    DumpLog();
    return $ret;
}

BEGIN { $TYPEINFO{defineMultipath} = ["function", "boolean", ["map", "string", "string"]]; }
sub defineMultipath($) {
    my ($dm) = @_;

    my $ret = $lib_ref->DefineMultipath ($dm);
    DumpLog();
    return $ret;
}

BEGIN { $TYPEINFO{getGlobalSettings} = ["function", ["map", "string", "string"]]; }
sub getGlobalSettings() {
    my %globalsettings = %{$lib_ref->GetGlobalSettings () || {}};

    # remove "__lines" key - it's internal
    my $idx = $lines_cache_index++;
    $globalsettings{"lines_cache_id"} = $idx;
    $lines_cache[$idx] = delete( $globalsettings{'__lines'} );

    # if there is "stage1_dev" key then convert the values to single string
    if (defined $globalsettings{'stage1_dev'})
    {
	my $string = join(",",@{$globalsettings{'stage1_dev'}}) ;
	$globalsettings{'stage1_dev'} = $string;
    }
   
    my %ret;
    # convert data to string type
    while ((my $key, my $value) = each %globalsettings) {
	$ret{"$key"} = "$value";
    }

    return \%ret; 
}

BEGIN { $TYPEINFO{setGlobalSettings} = ["function", "boolean", ["map", "string", "string"]]; }
sub setGlobalSettings($) {
    my ($globals) = @_;
    my %globalsettings = %{$globals};

    # if there is "stage1_dev" key then convert the value from single
    # string back to an array
    if (defined $globalsettings{'stage1_dev'}) {
	# split device string into a list
	my @devices = split(',', $globalsettings{'stage1_dev'});
	$globalsettings{'stage1_dev'} = \@devices;
    }


    my $index = exists($globalsettings{"lines_cache_id"}) ?
	$globalsettings{"lines_cache_id"} : undef;
    if ((defined($index)) && ($index ne "")) {
	$globalsettings{"__lines"} = $lines_cache[$index];
    }

    my $ret = $lib_ref->SetGlobalSettings (\%globalsettings);
    DumpLog();
    return $ret;
}

BEGIN { $TYPEINFO{getSections} = ["function", ["list", ["map", "string", "any"]]]; }
sub getSections() {
    my @sections = @{$lib_ref->GetSections () || []};

    # remove "__lines" key - it's internal
    # FIXME: this should be done in Bootloader::Core which can do
    # house holding of its internals by itself!!
    foreach my $section (@sections) { 
	my $index = $lines_cache_index++;
	$lines_cache[$index] = $section->{'__lines'};
	delete $section->{'__lines'};
	$section->{"lines_cache_id"} = $index;
    }
    DumpLog();
    return \@sections;
}

BEGIN { $TYPEINFO{setSections} = ["function", "boolean", ["list", ["map", "string", "any"]]]; }
sub setSections($) {
    my ($sections) = @_;

    my @sections = @{$sections || []};
    foreach my $section (@sections) {
	my $index = exists($section->{"lines_cache_id"}) ?
	    $section->{"lines_cache_id"} : undef;
	if (defined($index))
	{
	    $section->{"__lines"} = $lines_cache[$index];
	}
    }
    my $ret = $lib_ref->SetSections($sections);
    DumpLog();
    return $ret;
}

# handle native config file text
#
BEGIN { $TYPEINFO{setFilesContents} = ["function", "boolean", ["map", "string", "string"]]; }
sub setFilesContents($) {
    my ($contents) = @_;

    my $ret = $lib_ref->SetFilesContents($contents);

    DumpLog();
    return $ret; 
}

BEGIN { $TYPEINFO{getFilesContents} = ["function", ["map", "string", "string"]]; }
sub getFilesContents() {
    my $ret = $lib_ref->GetFilesContents();
    
    DumpLog();
    return $ret; 
}


BEGIN { $TYPEINFO{setMountPoints} = ["function", "boolean", ["map", "string", "string"]]; }
sub setMountPoints($) {
    my ($dm) = @_;
    my $ret = $lib_ref->DefineMountPoints ($dm);

    DumpLog();
    return $ret; 
}

BEGIN { $TYPEINFO{setPartitions} = ["function", "boolean", ["list", ["list", "string"]]]; }
sub setPartitions($) {
    my ($dm) = @_;
    my $ret = $lib_ref->DefinePartitions($dm);

    DumpLog();
    return $ret; 
}

BEGIN { $TYPEINFO{setMDArrays} = ["function", "boolean", ["map", "string", ["list", "string"]]]; }
sub setMDArrays($) {
    my ($dm) = @_;
    my $ret = $lib_ref->DefineMDArrays($dm);

    DumpLog();
    return $ret; 
}


# import fails if we cannot create the object
$lib_ref;
