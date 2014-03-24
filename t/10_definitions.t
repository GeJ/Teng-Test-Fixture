use strict;
use warnings;

use Test::More;
use Test::Deep;

use Teng::Test::Fixture::Definition;

use Data::Dumper;

my $class = 'Teng::Test::Fixture::Definition';

{
    my %args = (
            name       => 'A_Person',
            definition => {
                    new   => 'Person',
                    using => {name => 'bob'},
                },
            fixtures   => {A_Person => 1},
        );
    my $def = $class->new(%args);

    isa_ok($def, $class, "new simple object");

    is($def->name, 'A_Person', 'with its name,');

    my %definition = %{$args{definition}};
    cmp_deeply(
            $def->definition,
            \%definition,
            'its definition,',
        );

    cmp_deeply(
            $def->fixtures,
            {A_Person => 1},
            'its fixtures,',
        );

    cmp_deeply(
            $def->args,
            {name => 'bob'},
            'its args,',
        );
    cmp_deeply(
            $def->requires,
            {},
            'an empty hash',
        );

    is($def->table,    'Person', 'its table');
    is($def->group,    undef,    'an undef group,',);
    is($def->next,     undef,    'and an undef next.',);
}

{
    my %args = (
            name       => 'A_Group',
            definition => [qw(some_item some_other_item)],
            fixtures   => {
                    A_Group         => 1,
                    some_item       => 1,
                    some_other_item => 1,
                },
        );
    my $def = $class->new(%args);

    isa_ok($def, $class, "new group object");

    is($def->name, 'A_Group', 'with its name,');

    my @definition = @{$args{definition}};
    cmp_deeply(
            $def->group,
            \@definition,
            'its group,',
        );

    cmp_deeply(
            $def->fixtures,
            {A_Group=> 1, some_item => 1, some_other_item => 1,},
            'its fixtures,',
        );

    cmp_deeply(
            $def->definition,
            {},
            'its empty definition',
        );
    cmp_deeply(
            $def->requires,
            {},
            'an empty hash',
        );

    is($def->args,     undef,    'an undef args');
    is($def->table,    undef,    'an undef table');
    is($def->next,     undef,    'and an undef next.',);
}


done_testing;

