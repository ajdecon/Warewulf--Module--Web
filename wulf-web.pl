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
set 'show_errors' => 1;

# Use a persistent connection to Warewulf facilities.
my $db = Warewulf::DataStore->new();
my $pxe = Warewulf::Provision::Pxelinux->new();
my $dhcp = Warewulf::Provision::DhcpFactory->new();
my $hostsfile = Warewulf::Provision::HostsFile->new();

# Begin common functions.

sub ww_name_by_id {
	my $type = shift;
	my $objid = shift;
	my $objectSet = $db->get_objects($type,"_id",($objid));
	if ($objectSet->count() < 1) {
		warn "No object present for $objid!";
		return;
	}
	return ($objectSet->get_object(0))->get("name");
}

sub ww_id_by_name {
	my $type = shift;
	my $objname = shift;
	my $objectSet = $db->get_objects($type,"name",($objname));
	if ($objectSet->count() < 1) {
		warn "No object present for $objname!";
		return;
	}
	return ($objectSet->get_object(0))->get("_id");
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

post '/node/:name' => sub {

	# Get good values for parameters
	my %inputs = params;
	my $name = $inputs{'name'};
	my $id = $inputs{'id'};
	my $cluster = $inputs{'cluster'};
	my $vnfsid = ww_id_by_name('vnfs',$inputs{'vnfs'});
	my $bootstrapid = ww_id_by_name('bootstrap',$inputs{'bootstrap'});
	# Ludicrous array unrolling follows...
	my @files = $inputs{'files'};
	my @fileids;
	foreach my $outer (@files) {
		if (ref($outer) eq 'ARRAY') {
			my @outlist = @{$outer};
			foreach my $inner (@outlist) {
				push(@fileids,ww_id_by_name('file',$inner));
			}
		} else {
			push(@fileids,ww_id_by_name('file',$outer));
		}
	}
	# Now for the netdevs
	my %netdevs;
	foreach my $param (sort keys %inputs) {
		if ($param =~ /(\w+)-ipaddr/) {
			$netdevs{$1}{'ipaddr'} = $inputs{$param};
		} elsif ($param =~ /(\w+)-netmask/) {
			$netdevs{$1}{'netmask'} = $inputs{$param};
		}
	}

	# Get node object.
	my $nodeSet = $db->get_objects('node','_id',($id));
	my $node = $nodeSet->get_object(0);
	
	# Set variables for node object.
	$node->set('name',$name);
	$node->set('vnfsid',$vnfsid);
	$node->set('bootstrapid',$bootstrapid);
	$node->set('fileids',@fileids);
	if (uc($cluster) eq 'UNDEF') {
		$node->del('cluster');
	} else {
		$node->set('cluster',$cluster);
	}
	foreach my $nd ($node->get('netdevs')) {
		if ($netdevs{$nd->get('name')}{'ipaddr'}) {
			$nd->set('ipaddr', $netdevs{$nd->get('name')}{'ipaddr'});
			$nd->set('netmask', $netdevs{$nd->get('name')}{'netmask'});	
		}
	}

	# Persist and update Warewulf
	$db->persist($nodeSet);
	$dhcp->persist();
	$hostsfile->update_datastore();
	$pxe->update($node);

	template 'success.tt', {
		'newaddr' => "/node/$name"
	};

};

dance;
