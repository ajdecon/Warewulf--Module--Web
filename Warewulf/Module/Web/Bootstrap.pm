#!/usr/bin/env perl

package Warewulf::Module::Web::Bootstrap;

use Dancer;
use Template;
use Warewulf::DataStore;
use Warewulf::Util;
use Warewulf::Module::Web::Common;

set 'template' => 'template_toolkit';
prefix '/bootstrap';
my $type = 'bootstrap';

get '/all' => {

    my $db = Warewulf::DataStore->new();
    my @objects = ($db->get_objects($type,'name',()))->get_list();
    my %objdata;
    foreach my $o (@objects) {
        %objdata{$o->get('name')}{'size'} = $o->get('size');
        %objdata{$o->get('name')}{'size_mb'} = sprintf('%.1f',$o->get('size')/(1024*1024));
    }

    template "$type/all.tt", {
        'objects' => %objdata,
    };
};

post '/upload' => {

};

post '/delete' => {

};
