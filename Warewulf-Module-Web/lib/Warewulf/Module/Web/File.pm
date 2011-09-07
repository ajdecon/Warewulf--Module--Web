#!/usr/bin/env perl

package Warewulf::Module::Web::File;

use Dancer;
use Template;
use Warewulf::DataStore;
use Warewulf::Util;

set 'template' => 'template_toolkit';
set 'layout' => 'main';

prefix '/file';

my $db = Warewulf::DataStore->new();

# Display file list

get '/' => sub {
	forward('/file/all');
};

get '/all' => sub {

	my $fileSet = $db->get_objects('file','name',());
	my %fileList;
	foreach my $file ($fileSet->get_list()) {
		$fileList{$file->get('name')} = sprintf("%f.",$file->get('size'));
	}

	template 'file/all.tt', {
		'file' => \%fileList,
	};

};

# Delete existing file
post '/delete' => sub {

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

post '/upload' => sub {
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
		'newaddr' => "/file/view/$name",
	};
		
	
};

# Show file information
get '/view/:name' => sub {
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

	template 'file/view.tt', {
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
post '/set/:name' => sub {
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
		'newaddr' => "/file/view/$name",
	};

};


