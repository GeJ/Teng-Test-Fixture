package Teng::Test::Fixture;
use 5.008005;
use strict;
use warnings;
use utf8;

our $VERSION = "0.01";

use Carp;
use Class::Accessor::Lite 0.05 (
    ro  => [qw(schema _resolver)],
    rw  => [qw(_in_transaction _cache)],
);
use Scalar::Util qw(blessed);

use Teng::Test::Fixture::Definition;
use Teng::Test::Fixture::DependencyResolver;

sub new { # {{{ 
    my $proto = shift;
    my $class = (ref $proto) ? ref($proto) : $proto;
    my %args  = @_==1 ? %{$_[0]} : @_;

    foreach my $mandatory (qw(schema)) {
        croak "Missing mandatory '$mandatory' parameter"
            unless defined $args{$mandatory};
    }

    my $schema = $args{schema};
    if (blessed($schema) && $schema->isa('Teng::Schema')) {
        $schema = $schema->instance;
    }

    croak "'schema' parameter is not a Teng object"
        unless (blessed($schema) && $schema->isa('Teng'));
    
    my $self = bless {
            schema          => $schema,
            _in_transaction => 0,
            _cache          => {},
            _resolver       => Teng::Test::Fixture::DependencyResolver->new(),
        },
        $class;

    # Build all the fixtures definition. First, we make it sure that all
    # definitions are valid when we instantiate the Fixture. Second, we feed
    # the dependency resolvers for future use.
    foreach my $fix_name ($self->all_fixture_names) {
        my $def = $self->_build_definition($fix_name);
        my (@requires, @wants);
        if ($def->group) {
            @requires = @{$def->group};
        }
        else {
            if ($def->next) {
                @wants = @{$def->next};
            }
            if ($def->requires) {
                @requires = keys %{$def->requires};
            }
        }
        $self->_resolver->add_node(
                $fix_name,
                {requires => \@requires, wants => \@wants}
            );
    }

    return $self;
} # }}}

sub _build_definition { # {{{
    my ($self, $fixture) = @_;
    return Teng::Test::Fixture::Definition->new({
            name       => $fixture,
            definition => $self->get_definition($fixture),
            fixtures   => { map { $_ => 1 } $self->all_fixture_names },
        });
} # }}}

sub fixture_loaded { exists $_[0]->_cache->{$_[1]} }
sub is_loaded      { exists $_[0]->_cache->{$_[1]} }

sub get_result { # {{{
    my ($self, $fixture) = @_;

    unless ( $self->is_loaded($fixture) ) {
        carp("Fixture '$fixture' was never loaded");
        return;
    }
    return $self->_get_from_cache($fixture);
} # }}}

sub _get_from_cache { $_[0]->_cache->{$_[1]} }

sub load { # {{{
    my ($self, @fixtures) = @_;

    # :TODO: start transaction
    if (not $self->_in_transaction) {
        $self->schema->txn_begin;
        $self->_in_transaction(1);
    }

    my @db_objects;
    foreach my $fixture (@fixtures) {
        my $def = $self->_build_definition($fixture);
        if ($def->group) {
            push @db_objects, $self->load(@{$def->group});
        }
        elsif ($self->is_loaded($fixture)) {
            push @db_objects, $self->_get_from_cache($fixture);
        }
        else {
            foreach my $fix ($self->_resolver->resolve($fixture)) {
                my $db_object = $self->_load_fixture($fix);
                push @db_objects, $db_object
                    if ($fix eq $fixture);
            }
        }
    }
    return unless defined wantarray();
    return (wantarray) ? @db_objects : $db_objects[0];
} # }}}

sub _load_fixture { # {{{
    my ($self, $fixture) = @_;

    my $definition = $self->_build_definition($fixture);
    
    my %args = %{$definition->args};
    foreach my $require ($definition->required_fixtures) {
        my $req_fixture = $self->_get_from_cache($require);
        foreach my $required_field (@{$definition->requires->{$require}}) {
            my ($our, $their) = @{$required_field}{qw(our their)};
            $args{$our} = $req_fixture->$their;
        }
    }

    my $obj = $self->schema->insert($definition->table, \%args);
    $self->_add_to_cache($fixture, $obj);
    return $obj;
} # }}}

sub unload { # {{{
    my $self = shift;
    if ($self->_in_transaction) {
        $self->schema->txn_rollback;
        $self->_cache({});
        $self->_in_transaction(0);
    }
    return 1;
} # }}}

sub DESTROY { $_[0]->unload }

# DBIC::EasyFixture compat
sub _add_to_cache { $_[0]->_cache->{$_[1]} = $_[2] }


sub all_fixture_names {
    croak("You must override all_fixture_names() in a subclass");
}

sub get_definition {
    croak("You must override get_definition() in a subclass");
}

1;
__END__

=encoding utf-8

=head1 NAME

Teng::Test::Fixture - Manage your test data with Teng.

=head1 SYNOPSIS

    package My::Fixtures;
    use parent 'Teng::Test::Fixture';
    
    my %definitions = ( ... );
    
    sub all_fixture_names { return keys %definitions };
    sub get_definition    { return $definition{$_[1]} };

And in your test code :

    use My::Fixtures;
    
    my $fixture = My::Fixtures->new( schema => $teng );
    my $row = $fixture->load('something');
    
    # run your tests
    
    $fixtures->unload;

=head1 DESCRIPTION

Teng::Test::Fixture is a port of Ovid's L<DBIx::Class::EasyFixture> to be
used with L<Teng>.

=head1 METHODS

=head2 Subclass->new(%args | \%args)

Returns a new instance of a Teng::Test::Fixture subclass. It performs various
checks against the fixtures definitions and eventually dies when an error is
encountered.

I<%args> are :

=over 4

=item schema (mandatory)

A L<Teng> instance.

=back

=head2 $fixture->all_fixture_names() :Array[Str]

This method B<MUST> be implemented in the subclass. It returns a list of the
names of all the defined fixtures.

=head2 $fixture->get_definition($name :Str) :HashRef

This method B<MUST> be implemented in the subclass. It returns a hash
reference with the definition of the fixture named C<$name>.

=head2 $fixture->load($name :Str | @names :Array[Str])

Load the fixture named C<$name>. It is possible to load several fixtures with
one method call by using a list of names.

In scalar context this method will return the first fixture loaded. In list
context it will return all the fixtures that were called in the invocation.

=head2 $fixture->is_loaded($name :Str) :Bool

Return true if a fixture named C<$name> has already been loaded and false
otherwise.

=head1 FIXTURES

For a more comple example, you can look at F<t/lib/My/Fixtures.pm>.

Fixture definitions are usually declared in a hash using the following 
syntax :

    $fixture_name => {
        new   => $table,
        using => {
            $column1 => $value1,
            $column2 => $value2,
            ...
        },
    }

where :

=over 4

=item C<$fixture_name> is the unique name for your fixture.

=item C<$table> is the name of the table as it is defined in your L<Teng::Schema>

=item C<$columnN> and C<$valueN> are the names and values to use for your object

=back

=head2 Using another fixture

In the case of say a foreign key, you may want to use the result of another
fixture when creating a new one.

Let's say that we have a C<company> table with an C<id> and a C<name> columns
and we want to add some employees to it. There are several ways to achieve
this result :

    'some_company' => {
        new   => 'company',
        using => { name => 'My Corp Ltd.' },
    },
    
    'first_employee' => {
        new   => 'employee',
        using => {
            first_name => 'Arthur',
            last_name  => 'Dent',
        },
        requires => {
            'some_company' => { our => 'company_id', their => 'id' },
        }
    },

You declare that the I<first_employee> fixture will need I<some_company> and
take the object's C<id> value and use this for its own C<company_id> column.

This is the most verbose syntax and it can be simplified like this :

    'second_employee' => {
        new   => 'employee',
        using => {
            first_name => 'Ford',
            last_name  => 'Prefect',
            company_id => { 'some_company' => 'id' }, # using a hash reference
        },
    },

or like this :

    'third_employee' => {
        new   => 'employee',
        using => {
            first_name => 'Zaphod',
            last_name  => 'Beeblebrox',
            company_id => [ 'some_company', 'id' ], # using an array reference
        },
    },

I<If> the columns in both tables had the same name (ie. the C<company> table had
a C<company_id> column), this could have shortened as :

    'fourth_employee' => {
        new   => 'employee',
        using => {
            first_name => 'Tricia',
            last_name  => 'McMillan',
            company_id => \'some_company', # using a scalar reference
        }
    },

When using compound keys, you can declare the relationships between the fixtures
like this :

    'some_fixture' => {
        new => 'table_A',
        using => {
            pk_A1 => 'foo',
            pk_A2 => 'bar',
            baz   => 'quux',
        }
    },
    
    'another_fixture' => {
        new   => 'table_B',
        using => {
            xyzzy => 'fred',
        }
        requires => {
            some_fixture => [
                { our => 'fk_1', their => 'pk_A1' },
                { our => 'fk_2', their => 'pk_A2' },
            ],
        }
    }

Note : this fixture is not yet implemented in L<DBIx::Class::EasyFixture>.
            
'Requires' fixtures are not returned when calling C<< $fixture->load() >>.

=head2 Using additional fixtures

After loading an object, you may need to create other objects in other tables
to have a consistent data set. Rather than calling C<load()> with a long list
of fixtures, you can declare that some fixture must be loaded after the main
one. You need to write :

    'some_employee' => {
        new   => 'employee',
        using => { ... },
        next  => [qw(some_parking_spot some_desk some_gym_membership)],
    },

This will make sure that calling C<< $fixtures->load('some_employee') >> will
also load C<some_parking_spot>, C<some_desk> and C<some_gym_membership>.

'Next' fixtures are not returned when calling C<< $fixture->load() >>.

=head2 Group fixtures

You can also create aliases to a group of fixtures like this :

    'all_employees' => [qw(first_employee second_employee third_employee)],

Then calling C<< $fixture->load('all_employees') >> will load the three fixtures.
If the method was called in a list context, the objects for the three employees
will be returned.

=head1 SEE ALSO

L<DBIx::Class::EasyFixture> L<DBIx::Class::EasyFixture::Tutorial> 

=head1 THANKS

Curtis "Ovid" Poe for the original module.

Everything that would work with his module but wouldn't with mine is most
certainly my fault and mine only.

=head1 LICENSE

Copyright (C) Geraud CONTINSOUZAS.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Geraud CONTINSOUZAS E<lt>gcs at cpan.orgE<gt>

=cut

