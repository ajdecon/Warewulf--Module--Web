#!/usr/bin/env perl

use Warewulf::DataStore;
use Warewulf::Util;
use Exporter;

my @EXPORT = qw(ww_get_object ww_get_full_list);


my $db = Warewulf::DataStore->new();
my @valid_types = ('vnfs', 'file', 'node', 'bootstrap');

sub ww_get_object {

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

sub ww_get_full_list {
    my $type = shift;
    return ($db->get_objects($type,'name',()))->get_list();
}

sub ww_validate_param {
    my $type = shift;
    my $attribute = shift;
    my $value = shift;

    return $value;

}

sub ww_del_object {

    my $type = shift;
    my $name = shift;
    my $object = ww_get_object($type,$name);
    $db->del($object);
}

sub ww_persist_object {
    my $object = shift;
    if ($object) {
        $db->persist($object);
    }
}
