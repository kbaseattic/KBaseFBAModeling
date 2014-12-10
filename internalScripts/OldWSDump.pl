#!/usr/bin/perl -w

use strict;
use MongoDB::Connection;

$|=1;

my $config = {
	host => "mongo.kbase.us",
	db_name => "workspace_service",
	auto_connect => 1,
	auto_reconnect => 1
};
my $conn = MongoDB::Connection->new(%$config);
die "Unable to connect: $@" if (!defined($conn));
my $db = $conn->get_database("workspace_service");
my $cursor = $db->get_collection( 'workspaces' )->find({});
open(my $fhh, ">", "WSObjects.txt");
open(my $fh, ">", "WS.txt");
print $fh "WS\tOwner\tDefaultPermissions\n";
print $fhh "WS\tID\tType\tModdate\tCommand\tUUID\tInstance\tCHSUM\tOwner\n";
while (my $object = $cursor->next) {
        print $object->{id}."\n";
        print $fh $object->{id}."\t".$object->{owner}."\t".$object->{defaultPermissions}."\n";
        my $objs = $object->{objects};
        my $uuids = [];
        foreach my $id (keys(%{$objs})) {
                push(@{$uuids},$objs->{$id});
        }
        if (@{$uuids} > 0) {
                my $objcursor = $db->get_collection( 'workspaceObjects' )->find({uuid => {'$in' => $uuids}});
                while (my $obj = $objcursor->next) {
                        print $fhh $obj->{workspace}."\t".$obj->{id}."\t".$obj->{type}."\t".$obj->{moddate}."\t".$obj->{command}."\t".$obj->{uuid}."\t".$obj->{instance}."\t".$obj->{chsum}."\t".$obj->{owner}."\n";
                }
        }
}
my $objcursor = $db->get_collection( 'workspaceObjects' )->find({workspace => "NO_WORKSPACE"});
while (my $obj = $objcursor->next) {
	print $fhh $obj->{workspace}."\t".$obj->{id}."\t".$obj->{type}."\t".$obj->{moddate}."\t".$obj->{command}."\t".$obj->{uuid}."\t".$obj->{instance}."\t".$obj->{chsum}."\t".$obj->{owner}."\n";
}
close($fh);
close($fhh);

1;