#!/usr/bin/env perl

package Warewulf::Module::Web::File;

use Dancer;
use Template;
use Warewulf::DataStore;
use Warewulf::Util;

set 'template' => 'template_toolkit';

my $type = 'file';
my @attributes = ('name','uid','gid','size','checksum','mode','path','_id');

prefix '/file';

# Begin functions

# Check a named file parameter for validity
sub validate_file_param {

    my $name = shift;
    my $value = shift;

    if (lc($name) eq 'path') {
        if (not ($value =~ /^([a-zA-Z0-9\-_\/\.]+)$/)) {
        return 0;
    }
    } elsif (lc($name) eq ('uid' or 'gid') ) {
        if (not ($value =~ /^[0-9]+$/)) {
            return 0;
        }
    } elsif (lc($name) eq 'name') {
        if (not ($value =~ /^[a-zA-Z0-9\-_\.]+$/)) {
        return 0;
    }
    } elsif (lc($name) eq 'mode') {
        if (not ($value =~ /^[0-7]{3,4}$/)) {
        return 0;
    }
    } else {
        warn "Invalid parameter $name";
    return 0;
    }

    return $value;
}

# Begin route handlers

get '/all' => {

    my $db = Warewulf::DataStore->new();
    my @objects = ($db->get_objects($type,'name',()))->get_list();
    my %objdata;
    foreach my $o (@objects) {
        foreach my $a (@attributes) {
            %objdata{$o->get('name')}{"$a"} = $o->get("$a");
        }
    }

    template "$type/all.tt", {
        'objects' => %objdata,
    };
};


get '/view/:name' => {

    my $db = Warewulf::DataStore->new();
    my $name = params->{name};
    my @objects = ( $db->get_objects($type,'name',($name)) )->get_list();

    if (@objects==0) {
        warn "$type $name not found!";
        return;
    } elsif (@objects>1) {
        warn "More than one match to $type $name!";
        return;
    }

    my $o = $objects[0];
    my %objdata;
    foreach my $a (@attributes) {
        %objdata{"$a"} = $o->get("$a");
    }

    template "$type/view.tt", {
        'objects' => %objdata,
    };

};

post '/set/:name' => {

    my $db = Warewulf::DataStore->new();
    my $name = params->{name};
    my @objects = ( $db->get_objects($type,'name',($name)) )->get_list();

    if (@objects==0) {
        warn "$type $name not found!";
        return;
    } elsif (@objects>1) {
        warn "More than one match to $type $name!";
        return;
    }

    my $object = $objects[0];
    my %pars = params;
    foreach my $a (@attributes) {
        if ($pars{"$a"}) {
            my $valid = validate_file_param($a,$pars{"a"});
            if ($valid) {
                $object->set("$a",$valid);
            }
        }
    }

    $db->persist($object);

    template "$type/success.tt", {
        'newaddr' => "/$type",
    };
};


post '/delete' => {

    my $db = Warewulf::DataStore->new();
    my @nameParams = params->{name};
    # Need to double-unroll array
    my @names;
    if (ref($nameParams[0]) eq 'ARRAY') {
        foreach my $item (@{$nameParams[0]}) {
        push(@names,$item);
    }
    } else {
        push(@names,$nameParams[0]);
    }
    my @objects = @db->get_objects($type,'name',@names);

    $db->del_object($object[0]);

    template "$type/success.tt", {
        'newaddr' => "/$type",
    };    
};


post '/upload' => {
    
    my $db = Warewulf::DataStore->new();

    my $upload = upload('file');
    my $name = $upload->basename();
    my $overwrite = params->{overwrite};
    my $path = $upload->tempname();
    my $digest = digest_file_hex_md5($upload->tempname());
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($path);
    my $objectSet = $db->get_objects($type,'name',($name));
    my @objectList = $objectSet->get_list();
    my $file;
    if (scalar(@objectList) == 1) {
        if (not $overwrite) {
            print "$type $name already exists!\n";
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

    template "$type/success.tt", {
        'newaddr' => "/$type",
    };
};


