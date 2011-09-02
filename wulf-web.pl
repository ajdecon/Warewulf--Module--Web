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
use Warewulf::Util;

# Use Template-Toolkit for template files.
set 'template' => 'template_toolkit';
set 'show_errors' => 1;

# Use a persistent connection to Warewulf facilities.
my $db = Warewulf::DataStore->new();
my $pxe = Warewulf::Provision::Pxelinux->new();
my $dhcp = Warewulf::Provision::DhcpFactory->new();
my $hostsfile = Warewulf::Provision::HostsFile->new();

###############################################################################
# Begin common functions.
#
# ww_name_by_id(object_type, object_id)
#   Return name of Warewulf object from ID
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

# Random string
sub rand_string($) {
	my $length = shift;
	my @chars=('a'..'z');
	my $rs;
	foreach (1..$length) {
		$rs.=$chars[rand @chars];
	}
	return $rs;
}

###############################################################################
# Begin route handlers.
#
# Index page: show a basic provisioning view.
get '/' => sub {
	forward '/node';
};

get '/node' => sub {
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

# Return node control page (GET)
get '/node/:name' => sub {
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
		'kargs' => $kargs,
		'filesystems' => $filesystems,
		'diskpartition' => $diskpartition,
		'diskformat' => $diskformat,
		'bootlocal' => $bootlocal,
	};
};

# Set node properties (POST)
post '/node/:name' => sub {
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
		'newaddr' => "/node/$name"
	};

};

# Display vnfs list
get '/vnfs' => sub {

	my $vnfsSet = $db->get_objects('vnfs','name',());
	my %vnfsList;
	foreach my $vnfs ($vnfsSet->get_list()) {
		$vnfsList{$vnfs->get('name')} = sprintf("%.1f",$vnfs->get('size')/(1024*1024));
	}

	template 'vnfs.tt', {
		'vnfs' => \%vnfsList,
	};

};

# Delete existing VNFS
post '/vnfs/delete' => sub {

	# Get list of VNFS's to delete.
	# If >1 item, needs to be double-unrolled.
	my @vnfsParams = params->{vnfs};
	my @vnfsNames;
	foreach my $item (@vnfsParams) {
		if (ref($item) eq 'ARRAY') {
			foreach my $subitem (@{$item}) {
				push(@vnfsNames,$subitem);
			}
		} else {
			push(@vnfsNames,$item);
		}
	}

	# Get VNFS objects to be deleted.
	my $vnfsSet = $db->get_objects('vnfs','name',@vnfsNames);
	if ($vnfsSet->count() < @vnfsNames) {
		print "Only found " . $vnfsSet->count() . " of the " . @vnfsNames . " VNFS's\n";
		return;	
	}
	$db->del_object($vnfsSet);

	template 'success.tt', {
		'newaddr'=>"/vnfs",
	};
};

# TODO: Complete VNFS upload option.
post '/vnfs/upload' => sub {

	my $upload = upload('vnfs');
	my $basename = $upload->basename();

};

# Display bootstrap list
get '/bootstrap' => sub {

	my $bootstrapSet = $db->get_objects('bootstrap','name',());
	my %bootstrapList;
	foreach my $bootstrap ($bootstrapSet->get_list()) {
		$bootstrapList{$bootstrap->get('name')} = sprintf("%.1f",$bootstrap->get('size')/(1024*1024));
	}

	template 'bootstrap.tt', {
		'bootstrap' => \%bootstrapList,
	};

};

# Delete existing bootstrap
post '/bootstrap/delete' => sub {

	# Get list of VNFS's to delete.
	# If >1 item, needs to be double-unrolled.
	my @bootstrapParams = params->{bootstrap};
	my @bootstrapNames;
	foreach my $item (@bootstrapParams) {
		if (ref($item) eq 'ARRAY') {
			foreach my $subitem (@{$item}) {
				push(@bootstrapNames,$subitem);
			}
		} else {
			push(@bootstrapNames,$item);
		}
	}

	# Get VNFS objects to be deleted.
	my $bootstrapSet = $db->get_objects('bootstrap','name',@bootstrapNames);
	if ($bootstrapSet->count() < @bootstrapNames) {
		print "Only found " . $bootstrapSet->count() . " of the " . @bootstrapNames . " VNFS's\n";
		return;	
	}
	$db->del_object($bootstrapSet);

	template 'success.tt', {
		'newaddr'=>"/bootstrap",
	};
};

# Display file list
get '/file' => sub {

	my $fileSet = $db->get_objects('file','name',());
	my %fileList;
	foreach my $file ($fileSet->get_list()) {
		$fileList{$file->get('name')} = sprintf("%f.",$file->get('size'));
	}

	template 'file.tt', {
		'file' => \%fileList,
	};

};

# Delete existing file
post '/file/delete' => sub {

	# Get list of VNFS's to delete.
	# If >1 item, needs to be double-unrolled.
	my @fileParams = params->{file};
	my @fileNames;
	foreach my $item (@fileParams) {
		if (ref($item) eq 'ARRAY') {
			foreach my $subitem (@{$item}) {
				push(@fileNames,$subitem);
			}
		} else {
			push(@fileNames,$item);
		}
	}

	# Get VNFS objects to be deleted.
	my $fileSet = $db->get_objects('file','name',@fileNames);
	if ($fileSet->count() < @fileNames) {
		print "Only found " . $fileSet->count() . " of the " . @fileNames . " VNFS's\n";
		return;	
	}
	$db->del_object($fileSet);

	template 'success.tt', {
		'newaddr'=>"/file",
	};
};

post '/new/file' => sub {
	my $upload = upload('file');
	my $name = $upload->basename();
	my $overwrite = params->{overwrite};
	my $path = $upload->tempname();
	my $digest = digest_file_hex_md5($upload->tempname());
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($path);
	my $objectSet = $db->get_objects('file','name',($name));
	my @objectList = $objectSet->get_list();
	my $file;
	if (scalar(@objectList) == 1) {
		if (not $overwrite) {
			print "File $name already exists!\n";
			return;	
		} else {
			$file = $objectList[0];
		}
	} else {
		$file = Warewulf::DSOFactory->new('file');
	}
	$db->persist($file);
	$file->set('name',$name);
	$file->set('checksum',$digest);
	my $binstore = $db->binstore($file->get('_id'));
        my $buffer;
        open(FILE, $path);
        while(my $length = sysread(FILE, $buffer, 15*1024*1024)) {
                $binstore->put_chunk($buffer);
        }
        close FILE;
        $file->set("size", $size);
        $file->set("uid", $uid);
        $file->set("gid", $gid);
        $file->set("mode", sprintf("%05o", $mode & 07777));
        $file->set("path", $path);
        $db->persist($file);

	template 'success.tt', {
		'newaddr' => "/file/$name",
	};
		
	
};

# Show file information
get '/file/:name' => sub {
	my $name = params->{name};
	my $fileSet = $db->get_objects('file','name',($name));
	if ($fileSet->count() == 0) {
		print "No file $name found!\n";
	}
	my $file = $fileSet->get_object(0);
	my $uid = $file->get('uid');
	my $gid = $file->get('gid');
	my $path = $file->get('path');
	my $mode = $file->get('mode');
	my $id = $file->get('_id');

	# Get file contents
	my $contents = "";
	my $binstore = $db->binstore($file->get('_id'));
	while (my $buffer = $binstore->get_chunk()) {
		$contents = $contents . $buffer;
	}

	template 'fileview.tt', {
		'name' => $name,
		'id' => $id,
		'uid' => $uid,
		'gid' => $gid,
		'path' => $path,
		'mode' => $mode,
		'contents' => $contents,
	};

};

# Set file information
post '/file/:name' => sub {
	my $name = params->{name};
	my $id = params->{id};
	my $uid = params->{uid};
	my $gid = params->{gid};
	my $path = params->{path};
	my $mode = params->{mode};
	my $contents = params->{contents};
	my $persist = params->{persist};

	# Start checking for validity
	my $invalid = "";
	if (not ($path =~ /^([a-zA-Z0-9\-_\/\.]+)$/)) {
		$invalid = $invalid . " path ";
	}
	if (not ($uid =~ /^[0-9]+$/) ) {
		$invalid = $invalid . " uid ";
	}
	if (not ($gid =~ /^[0-9]+$/) ) {
		$invalid = $invalid . " gid ";
	}
	if (not ($name =~ /^[a-zA-Z0-9\-_\.]+$/)) {
		$invalid = $invalid . " name ";
	}
	if (not ($mode =~ /^[0-7]{3,4}$/)) {
		$invalid = $invalid . " mode ";
	}
	if ($invalid ne "") {
		print "Can't save! Invalid " . $invalid;
		return;
	}

	# Get file object
        my $fileSet = $db->get_objects('file','_id',($id));
        if ($fileSet->count() == 0) {
                print "No file $name found!\n";
        }
        my $file = $fileSet->get_object(0);
	
	# Check if contents changed; if so, change them.
#	if ($persist) {
		my $rand = rand_string(16);
        	my $tmpfile = "/tmp/wwsh.$rand";
	        my $digest1;
        	my $digest2;
		open(TMPFILE,">$tmpfile") or die "File error!\n";
		print TMPFILE $contents;
		close(TMPFILE);
		$digest1 = $file->get('checksum');
		$digest2 = digest_file_hex_md5($tmpfile);
		my $size = 0;

		if ($digest1 ne $digest2) {
		    my $buffer;
                    open(FILE, $tmpfile);
		    my $binstore = $db->binstore($file->get("_id"));
                    while(my $length = sysread(FILE, $buffer, 15*1024*1024)) {
			$binstore->put_chunk($buffer);
#                        if (! $size) {
#                            $file->set("format", &format($buffer));
#                        }
                        $size += $length;
                    }
		    close(FILE);
		    $file->set('checksum',$digest2);
		    $file->set('size',$size);
		    
		}
#	}

	# Save metadata
	$file->set('name',$name);
	$file->set('uid',$uid);
	$file->set('gid',$gid);
	$file->set('path',$path);
	$file->set('mode',$mode);


	$db->persist($fileSet);

	template 'success.tt', {
		'newaddr' => "/file/$name",
	};

};

# Run Dancer server.
dance;
