package My::Fixtures;
use 5.008005;
use strict;
use warnings;
use utf8;

use parent 'Teng::Test::Fixture';

my %definition_for = (
    a_division => {
        'new'   => 'division',
        'using' => { name => 'A Division', },
    },

    a_project => {
        'new'   => 'project',
        'using' => {
            'name'        => 'A Project',
            'division_id' => { 'a_division' => 'id' },
        },
    },

    a_team => {
        'new'   => 'team',
        'using' => {
            'name'        => 'A Team',
            # Require in using with a hash reference
            'division_id' => { 'a_division' => 'id' },
            # Require in using with an array reference
            'project_id'  => [ 'a_project',    'id' ],
        },
    },

    employee_john => {
        'new'      => 'employee',
        'using'    => { 'name' => 'John Smith', },
        'requires' => {
            # Explicit require
            'a_division' => { our => 'division_id', their => 'id' },
        },
        'next'     => ['john_in_team_a'],
    },

    john_in_team_a => {
        'new'      => 'team_members',
        'using'    => {
            'employee_id' => { 'employee_john' => 'id' },
        },
        'requires' => {
            # Compound key explicit require
            'a_team' => [
                { our => 'team_id',     their => 'id' },
                { our => 'division_id', their => 'division_id' },
            ],
        },
    }
);

sub get_definition {
    my ($self, $name) = @_;
    return $definition_for{$name};
}
 
sub all_fixture_names { return keys %definition_for }

1;
