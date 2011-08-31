#!/usr/bin/env perl
#
# wulf-web.pl
#   Basic web interface for Warewulf using the Dancer framework.
#   For the moment we're going for basic functionality and a 
#   proof-of-concept, we'll see where it goes from here.
#
#   Adam DeConinck @ R Systems NA, Inc.

use Dancer;
use Template;
use Warewulf::DataStore;
use Warewulf::Provision::Pxelinux;
use Warewulf::Provision:DhcpFactory;
use Warewulf::Provision::HostsFile;

# Use Template-Toolkit for template files.
set 'template' => 'template_toolkit';

# Begin common functions.

# get_ww_object ( type, field, value )
sub get_ww_object {
	$type = $_[0];
	$field = $_[1];
	$value = $_[2];

	# Query Warewulf datastore and make sure exactly one object is returned. 
	my $db = Warewulf::DataStore->new();
	my $objectSet = $db->get_objects($type,$field,$value);
	if ($objectSet->count() < 1) {
		warn "get_ww_object($type, $field, $value): No objects returned!";
		return;
	}
	if ($objectSet->count() > 1) {
		warn "get_ww_object($type, $field, $value): No objects returned!";
		return;
	}

	my $object = $objectSet->get_object(0);
	return $object;	
}

sub set_node_vnfs {

}

sub set_node_bootstrap {

}

# Begin route handlers.

get '/' => sub {

};
