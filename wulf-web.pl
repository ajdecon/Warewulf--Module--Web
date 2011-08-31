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
use Warewulf::Provision::DhcpFactory;
use Warewulf::Provision::HostsFile;

# Use Template-Toolkit for template files.
set 'template' => 'template_toolkit';

# Use a persistent connection to the db.
my $db = Warewulf::DataStore->new();


# Begin common functions.

sub ww_name_by_id {
	my $type = shift;
	my $objid = shift;
	my $objectSet = $db->get_objects($type,"_id",($objid));
	return ($objectSet->get_object(0))->get("name");
}

sub ww_avail_list {
	my $type = shift;
	my $objectSet = $db->get_objects($type,"_id",());
	my @list;
	foreach my $obj ($objectSet->get_list()) {
		push(@list,$obj->get("name"));
	}
	return @list;
}


# Begin route handlers.

# Index page: show a basic provisioning view.
get '/' => sub {

	my $nodeSet = $db->get_objects("node","name",());
	my %nodes;

	foreach my $n ($nodeSet->get_list()) {
		my $id = $n->get("_id");
		my $name = $n->get("name");
		my $cluster = $n->get("cluster");
		if (not $cluster) {
			$cluster = "UNDEF";
		}
		my $vnfs =  ww_name_by_id("vnfs", $n->get("vnfsid") );
		my $bootstrap = ww_name_by_id("bootstrap",$n->get("bootstrapid"));

		my @fileids = $n->get("fileids");
		my @files;
		foreach my $f (@fileids) {
			push(@files,ww_name_by_id("file",$f));
		}

		$nodes{$name} = {
			"name" => $name,
			"cluster" => $cluster,
			"vnfs" => $vnfs,
			"bootstrap" => $bootstrap,
			"files" => \@files,
		};
	}

	template 'provlist.tt', {
		'nodelist' => \%nodes
	};	

};

get '/node/:name' => sub {
	
	my $nodeSet = $db->get_objects("node","name",(params->{name}));
	my $n = $nodeSet->get_object(0);
	
        my $id = $n->get("_id");
	my $name = $n->get("name");
        my $cluster = $n->get("cluster");
        if (not $cluster) {
               $cluster = "UNDEF";
        }
        my $vnfs =  ww_name_by_id("vnfs", $n->get("vnfsid") );
        my $bootstrap = ww_name_by_id("bootstrap",$n->get("bootstrapid"));
        my @files;
        foreach my $f ($n->get("fileids")) {
                push(@files,ww_name_by_id("file",$f));
        }

	my %netdevs;
	
	 
        foreach my $nd ($n->get("netdevs")) {
		$netdevs{$nd->get("name")} = { "ipaddr" => $nd->get("ipaddr"), "netmask" => $nd->get("netmask") };
	}

	my @vnfslist = ww_avail_list("vnfs");
	my @bootlist = ww_avail_list("bootstrap");
	my @fileavail = ww_avail_list("file");
	
	my %filelist;
	for my $f (@fileavail) {
		
		foreach my $g (@files) {
			if ($f eq $g) {
				$filelist{$f} = "true";
			}
		}
		if (not $filelist{$f}) { 
			$filelist{$f} = "false";
		}
	}

	template 'node.tt', {
		'id' => $id,
		'name' => $name,
		'cluster' => $cluster,
		'vnfs' => $vnfs,
		'bootstrap' => $bootstrap,
		'files' => \@files,
		'netdevs' => \%netdevs,
		'vnfslist' => \@vnfslist,
		'bootlist' => \@bootlist,
		'filelist' => \%filelist,
	};
};

dance;
