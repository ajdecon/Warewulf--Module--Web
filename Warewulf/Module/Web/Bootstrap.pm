#!/usr/bin/env perl

package WWWeb::Bootstrap;

use Dancer;
use Template;
use Warewulf::DataStore;
use Warewulf::Util;

set 'template' => 'template_toolkit';
prefix '/bootstrap';

my $db = Warewulf::DataStore->new();

# Display bootstrap list
get '/' => sub {
	forward('/bootstrap/all');
};

get '/all' => sub {

	my $bootstrapSet = $db->get_objects('bootstrap','name',());
	my %bootstrapList;
	foreach my $bootstrap ($bootstrapSet->get_list()) {
		$bootstrapList{$bootstrap->get('name')} = sprintf("%.1f",$bootstrap->get('size')/(1024*1024));
	}

	template 'bootstrap/all.tt', {
		'bootstrap' => \%bootstrapList,
	};

};

# Delete existing bootstrap
post '/delete' => sub {

	# Get list of VNFS's to delete.
	# If >1 item, needs to be double-unrolled.
	my @bootstrapParams = params->{bootstrap};
	my @bootstrapNames;
	foreach my $item (@bootstrapParams) {
		if (ref($item) eq 'ARRAY') {
			foreach my $subitem (@{$item}) {
				push(@bootstrapNames,$subitem);
			}
		} else {
			push(@bootstrapNames,$item);
		}
	}

	# Get VNFS objects to be deleted.
	my $bootstrapSet = $db->get_objects('bootstrap','name',@bootstrapNames);
	if ($bootstrapSet->count() < @bootstrapNames) {
		print "Only found " . $bootstrapSet->count() . " of the " . @bootstrapNames . " VNFS's\n";
		return;	
	}
	$db->del_object($bootstrapSet);

	template 'success.tt', {
		'newaddr'=>"/bootstrap",
	};
};


