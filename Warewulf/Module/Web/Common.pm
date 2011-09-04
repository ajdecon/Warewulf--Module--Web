#!/usr/bin/env perl

use Dancer;
use Template;
use Warewulf::DataStore;
use Warewulf::Util;

set 'template' => 'template_toolkit';

my $db = Warewulf::DataStore->new();
