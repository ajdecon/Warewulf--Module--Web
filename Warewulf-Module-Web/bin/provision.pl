#!/usr/bin/env perl
#

use Warewulf::Provision::DhcpFactory;
use Warewulf::Provision::Pxelinux;
use Warewulf::DataStore;

# Get ID of node to update.

my $nodeid = $ARGV[0];

if (not ($nodeid =~ /^[0-9]+$/) ) {
	die "Not a valid number!\n";
}

my $db = Warewulf::DataStore->new();
my $dhcp = Warewulf::Provision::DhcpFactory->new();
my $pxe = Warewulf::Provision::Pxelinux->new();

my @nodeSet = ( $db->get_objects('node','_id',($nodeid)) )->get_list();
if (@nodeSet==0) {
	die "Could not find node $nodeid!\n";
}
my $node = $nodeSet[0];

$dhcp->persist();
$pxe->update($node);

print "Updated! Effective UID = $< $>\n";
