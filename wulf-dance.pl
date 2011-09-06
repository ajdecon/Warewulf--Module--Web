#!/usr/bin/env perl
# package Warewulf::Module::Web;

use Dancer;
use Template;
use WWWeb::Node;
use WWWeb::Vnfs;
use WWWeb::Bootstrap;
use WWWeb::File;

prefix undef;
set session => 'Simple';

before sub {

    if (! session('user') && request->path_info !~ m{^/login}) {
         var requested_path => request->path_info;
        request->path_info('/login');
    }
};

get '/login' => sub {
	template 'login.tt', { path => vars->{requested_path} };
};

post '/login' => sub {
	if (params->{user} eq 'admin' && params->{pass} eq 'wulf') {
		session user => params->{user};
		redirect params->{path} || '/';
	} else {
		redirect '/login?failed=1';
	}
};

get '/logout' => sub {
	session->destroy;
	redirect '/';
};

get '/' => sub {
	forward('/node/all');
};

dance;
