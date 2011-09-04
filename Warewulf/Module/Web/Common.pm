#!/usr/bin/env perl

use Warewulf::DataStore;
use Warewulf::Util;
use Exporter;

my @EXPORT = qw(&get_object &get_full_list);


my $db = Warewulf::DataStore->new();
my @valid_types = ('vnfs', 'file', 'node', 'bootstrap');

sub get_object {

    my $type = shift;
    my $name = shift;

    my $object_set = $db->get_objects($type,'name',($name));
    if ($object_set->count() == 0) {
        print "$type $name not found!\n;";
        return;
    } elsif ($object_set->count() > 1) {
        print "$name not unique in $type !\n";
    }

    my $object = $object_set->get_object(0);
    return $object;

};

sub get_full_list {
    my $type = shift;
    return ($db->get_objects($type,'name',()))->get_list();
}
