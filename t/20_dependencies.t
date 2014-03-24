use strict;
use warnings;

use Test::More;
use Test::Deep;

use Teng::Test::Fixture::DependencyResolver;

sub new_dr { Teng::Test::Fixture::DependencyResolver->new() }

{
    my $dr = new_dr();
    isa_ok( $dr,
            'Teng::Test::Fixture::DependencyResolver',
            'new DependencyResolver'
        );

    can_ok($dr, 'add_node');
    can_ok($dr, 'resolved');
    can_ok($dr, 'resolve');

    $dr->add_node('A', requires => 'B', wants => [qw(D C)]);
    cmp_deeply(
            $dr->_graph, # Shhhhh!
            {A => {requires => ['B'], wants => ['C', 'D',]}},
            'add a new node in the graph (with fixtures sorted)'
        );
    $dr->add_node('A', requires => 'E');
    cmp_deeply(
            $dr->_graph, # Shhhhh!
            {A => {requires => ['B', 'E'], wants => ['C', 'D',]}},
            q(adding new 'requires' to the same node merges them)
        );
    $dr->add_node('A', wants => 'F');
    cmp_deeply(
            $dr->_graph, # Shhhhh!
            {A => {requires => ['B', 'E'], wants => ['C', 'D', 'F']}},
            q(likewise with new 'wants')
        );
}

{
    my $dr = new_dr();
    $dr->add_node('A');
    cmp_deeply(
            [$dr->resolve('A')],
            ['A'],
            'resolve a single node');
    $dr->add_node('A', requires => 'B');
    $dr->add_node('B');
    cmp_deeply(
            [$dr->resolve('A')],
            [qw(B A)],
            'resolve a node with one requires');
    $dr->add_node('A', wants => 'C');
    $dr->add_node('C');
    cmp_deeply(
            [$dr->resolve('A')],
            [qw(B A C)],
            'resolve a node with one requires and one wants');
}

{
    my $dr = new_dr();
    $dr->add_node('A', requires => 'E');
    $dr->add_node('B', requires => [qw(A E F)], wants => [qw(C G)]);
    $dr->add_node('C', requires => [qw(E G)],   wants => 'D');
    $dr->add_node($_) for (qw(D E F));
    $dr->add_node('G',                          wants => 'H');
    $dr->add_node('H', requires => 'D');

    cmp_deeply(
            [$dr->resolve('B')],
            [qw(E A F B G D H C)],
            'resolve a moderately complex graph'
        );
}

done_testing;

