#!/usr/bin/env perl

package Warewulf::Module::Web::File;

use Dancer;
use Template;
use Warewulf::DataStore;
use Warewulf::Util;
use Warewulf::Module::Web::Common;

set 'template' => 'template_toolkit';

my $db = Warewulf::DataStore->new();
my $type = 'file';
my @attributes = ('name','uid','gid','size','checksum','mode','path','_id');

prefix '/file';

get '/all' => {

    my @objecs = ww_get_full_list($type);
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

};

get '/view/:name' => {

    my $object = ww_get_object($type,params->{name});
    my %objdata;
    foreach my $a (@attributes) {
        %objdata{"$a"} = $o->get("$a");
    }

    template "$type/view.tt", {
        'objects' => %objdata,
    };

};

post '/set/:name' => {
    my $object = ww_get_object($type,params->{name});
    my %pars = params;
    foreach my $a (@attributes) {
        if ($pars{"$a"}) {
            my $valid = ww_validate_param($type,$a,$pars{"a"});
            if ($valid) {
                $object->set("$a",$valid);
            }
        }
    }

    ww_persist_object($object);
};

post '/upload' => {
    


};

post '/delete' => {

    my $name = params{name};
    ww_del_object($type,$name);

};
