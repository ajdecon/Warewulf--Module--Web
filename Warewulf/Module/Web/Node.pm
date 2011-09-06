#!/usr/bin/env perl

#package Warewulf::Module::Web::Node;
package WWWeb::Node;

use Dancer;
use Template;
use Warewulf::DataStore;
use Warewulf::Provision::Pxelinux;
use Warewulf::Provision::DhcpFactory;
use Warewulf::Provision::HostsFile;
use Warewulf::Util;

set 'template' => 'template_toolkit';
set 'layout' => 'main';
set 'show_errors' => 1;

# Connections to Warewulf objects
my $db = Warewulf::DataStore->new();
my $pxe = Warewulf::Provision::Pxelinux->new();
my $dhcp = Warewulf::Provision::DhcpFactory->new();
my $hostsfile = Warewulf::Provision::HostsFile->new();


prefix '/node';

# Begin functions
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

# ww_avail_list
#   Return a list of all objects of a given type.
sub ww_avail_list {
	my $type = shift;
	my $objectSet = $db->get_objects($type,"_id",());
	my @list;
	foreach my $obj ($objectSet->get_list()) {
		push(@list,$obj->get("name"));
	}
	return @list;
}

# ww_id_by_name(object_type,object_name)
#   Return ID of Warewulf object from name.
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


# Begin route handlers
get '/all' => sub {
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
	template "node/all.tt", {
		'nodelist' => \%nodes
	};	
};

# Return node control page (GET)
get '/view/:name' => sub {
	# Get node object
	my $nodeSet = $db->get_objects("node","name",(params->{name}));
	my $n = $nodeSet->get_object(0);
	
	# Get all node properties.
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

	# Advanced options
	my $kargs = $n->get('kargs') or 'UNDEF';
	my $fstemp = $n->get('filesystems') or 'UNDEF';
	my $filesystems = "";
	if (ref($fstemp) eq 'ARRAY') {
		foreach my $fs (@{$fstemp}) {
			$filesystems .= "$fs,";
		}
	} else {
		$filesystems = $fstemp;
	}

	my $dptemp = $n->get('diskpartition') or 'UNDEF';
	my $diskpartition = "";
	if (ref($dptemp) eq 'ARRAY') {
		foreach my $dp (@{$dptemp}) {
			$diskpartition .= "$dp,";
		}
	} else {
		$diskpartition = $dptemp;
	}

	my $dftemp = $n->get('diskformat') or 'UNDEF';
	my $diskformat = "";
	if (ref($dftemp) eq 'ARRAY') {
		foreach my $df (@{$dftemp}) {
			$diskformat .= "$df,";
		}
	} else {
		$diskformat = $dftemp;
	}
	my $bootlocal = $n->get('bootlocal') or 0;
	
	# Write out page using template.
	template "node/view.tt", {
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
		'kargs' => $kargs,
		'filesystems' => $filesystems,
		'diskpartition' => $diskpartition,
		'diskformat' => $diskformat,
		'bootlocal' => $bootlocal,
	};
};

# Set node properties (POST)
post '/set/:name' => sub {
	# Get values for parameters
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
	if ($nodeSet->count() == 0) {
		warn "Can't find this node!\n";
		return;
	}
	my $node = $nodeSet->get_object(0);

	# Advanced options
	my $kargs = $inputs{'kargs'} . " ";
	if ($kargs and ($kargs ne 'UNDEF')) {
		$node->set('kargs',$kargs);
	} else {
		$node->del('kargs');
	}
	my @filesystems;
	if ($inputs{'filesystems'} and ($inputs{'filesystems'} ne 'UNDEF')) {
		@filesystems = split(/,/,$inputs{'filesystems'});
		$node->set('filesystems',@filesystems);
	} else {
		$node->del('filesystems');
	}
	my @diskformat;
	if ($inputs{'diskformat'} and ($inputs{'diskformat'} ne 'UNDEF')) {
		@diskformat = split(/,/,$inputs{'diskformat'});
		$node->set('diskformat',@diskformat);
	} else {
		$node->del('diskformat');
	}
	my @diskpartition;
	if ($inputs{'diskpartition'} and ($inputs{'diskpartition'} ne 'UNDEF')) {
		@diskpartition = split(/,/,$inputs{'diskpartition'});
		$node->set('diskpartition',@diskpartition);
	} else {
		$node->del('diskpartition');
	}
	my $bootlocal = $inputs{'bootlocal'};
	if ($bootlocal == 1) {
		$node->set('bootlocal',$bootlocal);
	} else {
		$node->del('bootlocal');
	}

		
	# Set variables for node object.
	$node->set('name',$name);
	$node->set('vnfsid',$vnfsid);
	$node->set('bootstrapid',$bootstrapid);
	$node->set('fileids',@fileids);
	if ( (uc($cluster) eq 'UNDEF') or ($cluster eq "") ){
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
		'newaddr' => "/node/view/$name"
	};

};


