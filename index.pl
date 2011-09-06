#!/usr/bin/env perl
#
# index.pl


use Dancer;
use Template;

use wwtest::node;

set 'template' => 'template_toolkit';
set 'show_errors' => 1;

prefix undef;

get '/' => sub {
	print "Index!\n\n";
};

dance;
