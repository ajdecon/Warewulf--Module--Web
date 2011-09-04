#!/usr/bin/env perl

package Warewulf::Module::Web::Node;

use Dancer;
use Template;
use Warewulf::DataStore;
use Warewulf::Util;

set 'template' => 'template_toolkit';

my $db = Warewulf::DataStore->new();

prefix '/node';

get '/view/:name' => {

};

post '/set/:name' => {

};

post '/upload' => {

};

post '/delete' => {

};
