#!/usr/bin/env perl
#

# package Warewulf::Module::Web;

use Dancer;
use Template;
use WWWeb::Node;

prefix undef;

get '/' => sub {
	forward('/node/all');
};

dance;
