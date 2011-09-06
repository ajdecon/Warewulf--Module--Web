#!/usr/bin/env perl
#

# package Warewulf::Module::Web;

use Dancer;
use Template;
use WWWeb::Node;
use WWWeb::Vnfs;
use WWWeb::Bootstrap;
use WWWeb::File;

prefix undef;

get '/' => sub {
	forward('/node/all');
};

dance;
