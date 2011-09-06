#!/usr/bin/env perl
#
# index.pl

package wwtest::node;

use Dancer;

set 'template' => 'template_toolkit';
set 'show_errors' => 1;

prefix '/node';

get '/' => sub {
	print "Node!\n\n";
};

