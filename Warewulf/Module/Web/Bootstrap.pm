#!/usr/bin/env perl

package Warewulf::Module::Web::Bootstrap;

use Dancer;
use Template;
use Warewulf::DataStore;
use Warewulf::Util;
use Warewulf::Module::Web::Common;

set 'template' => 'template_toolkit';

my $db = Warewulf::DataStore->new();
my $type = 'bootstrap';

prefix '/bootstrap';

get '/all' => {

    my @objecs = ww_get_full_list($type);
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
