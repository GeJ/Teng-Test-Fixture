use strict;
use warnings;

use Test::More;

use t::Util qw(db);

use My::Fixtures;

my $fixture = My::Fixtures->new(schema => db());
isa_ok($fixture, 'Teng::Test::Fixture');

my $john = $fixture->load('employee_john');
isa_ok($john, 'My::DB::Row::Employee');

done_testing;

