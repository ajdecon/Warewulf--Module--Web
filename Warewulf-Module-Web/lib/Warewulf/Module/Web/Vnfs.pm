#!/usr/bin/env perl

package Warewulf::Module::Web::Vnfs;

use Dancer;
use Template;
use Warewulf::DataStore;
use Warewulf::Util;

set 'template' => 'template_toolkit';

my $db = Warewulf::DataStore->new();

prefix '/vnfs';

# Display vnfs list

get '/' => sub {
	forward('/vnfs/all');
};

get '/all' => sub {

	my $vnfsSet = $db->get_objects('vnfs','name',());
	my %vnfsList;
	foreach my $vnfs ($vnfsSet->get_list()) {
		$vnfsList{$vnfs->get('name')} = sprintf("%.1f",$vnfs->get('size')/(1024*1024));
	}

	template "vnfs/all.tt", {
		'vnfs' => \%vnfsList,
	};

};

# Delete existing VNFS
post '/delete' => sub {

	# Get list of VNFS's to delete.
	# If >1 item, needs to be double-unrolled.
	my @vnfsParams = params->{vnfs};
	my @vnfsNames;
	foreach my $item (@vnfsParams) {
		if (ref($item) eq 'ARRAY') {
			foreach my $subitem (@{$item}) {
				push(@vnfsNames,$subitem);
			}
		} else {
			push(@vnfsNames,$item);
		}
	}

	# Get VNFS objects to be deleted.
	my $vnfsSet = $db->get_objects('vnfs','name',@vnfsNames);
	if ($vnfsSet->count() < @vnfsNames) {
		print "Only found " . $vnfsSet->count() . " of the " . @vnfsNames . " VNFS's\n";
		return;	
	}
	$db->del_object($vnfsSet);

	template 'success.tt', {
		'newaddr'=>"/vnfs",
	};
};


