#!/usr/bin/env perl

package Warewulf::Module::Web::Vnfs;

use Dancer;
use Template;
use Warewulf::DataStore;
use Warewulf::Util;

set 'template' => 'template_toolkit';

my $db = Warewulf::DataStore->new();

prefix '/vnfs';

get '/view/:name' => {

};

post '/set/:name' => {

};

post '/upload' => {

};

post '/delete' => {

};
