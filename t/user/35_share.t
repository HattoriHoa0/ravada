#!perl

use strict;
use warnings;

use Data::Dumper;
use Test::More;

use lib 't/lib';
use Test::Ravada;

no warnings "experimental::signatures";
use feature qw(signatures);

##############################################################

sub test_share($vm) {
    my $base = create_domain($vm->type);

    $base->prepare_base( user_admin );
    $base->is_public(1);

    my $user1 = create_user(new_domain_name(),$$);
    my $user2 = create_user(new_domain_name(),$$);
    is($user1->is_admin,0);

    my $req = Ravada::Request->clone(
        uid => $user1->id
        ,id_domain => $base->id
    );
    wait_request();
    my ($clone0) = grep { $_->{id_owner} == $user1->id } $base->clones;
    ok($clone0);
    my $clone = Ravada::Front::Domain->open($clone0->{id});

    my $list_bases_u1 = rvd_front->list_machines_user($user1);
    my ($clone_user1) = grep { $_->{name } eq $base->name } @$list_bases_u1;
    is(scalar(@{$clone_user1->{list_clones}}),1);

    my $list_bases_u2 = rvd_front->list_machines_user($user2);
    my ($clone_user2) = grep { $_->{name } eq $base->name } @$list_bases_u2;
    is(scalar(@{$clone_user2->{list_clones}}),0);

    $clone->share($user2);

    $list_bases_u2 = rvd_front->list_machines_user($user2);
    ($clone_user2) = grep { $_->{name } eq $base->name } @$list_bases_u2;
    is(scalar(@{$clone_user2->{list_clones}}),1);

    my $req2 = Ravada::Request->start_domain(
        uid => $user2->id
        ,id_domain => $clone->id
    );
    wait_request();
}

##############################################################

clean();
for my $vm_name ( vm_names() ) {

    my $vm;
    eval { $vm = rvd_back->search_vm($vm_name) };

    SKIP: {
        my $msg = "SKIPPED test: No $vm_name VM found ";
        if ($vm && $vm_name =~ /kvm/i && $>) {
            $msg = "SKIPPED: Test must run as root";
            $vm = undef;
        }

        diag($msg)      if !$vm;
        skip $msg,10    if !$vm;

        diag("Testing share on $vm_name");

        test_share($vm);
    }
}

end();
done_testing();
