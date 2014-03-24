# NAME

Teng::Test::Fixture - Manage your test data with Teng.

# SYNOPSIS

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

# DESCRIPTION

Teng::Test::Fixture is a port of Ovid's [DBIx::Class::EasyFixture](https://metacpan.org/pod/DBIx::Class::EasyFixture) to be
used with [Teng](https://metacpan.org/pod/Teng).

# METHODS

## `Subclass->new(%args | \%args)`

Returns a new instance of a Teng::Test::Fixture subclass. It performs various
checks against the fixtures definitions and eventually dies when an error is
encountered.

_%args_ are :

- schema (mandatory)

    A [Teng](https://metacpan.org/pod/Teng) instance.

## `$fixture->all_fixture_names() :Array[Str]`

This method __MUST__ be implemented in the subclass. It returns a list of the
names of all the defined fixtures.

## `$fixture->get_definition($name :Str) :HashRef`

This method __MUST__ be implemented in the subclass. It returns a hash
reference with the definition of the fixture named `$name`.

## `$fixture->load($name :Str | @names :Array[Str])`

Load the fixture named `$name`. It is possible to load several fixtures with
one method call by using a list of names.

In scalar context this method will return the first fixture loaded. In list
context it will return all the fixtures that were called in the invocation.

Note : group fixtures are expanded.

## `$fixture->is_loaded($name :Str) :Bool`

Return whether a fixture name `$name` has already been loaded.

# FIXTURES

Fixture definitions are usually declare in a hash using the following 
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

- `$fixture_name` is the unique name for your fixture.
- `$table` is the name of the table as it is defined in your [Teng::Schema](https://metacpan.org/pod/Teng::Schema)
- `$columnN` and `$valueN` are the names and values to use to create your object

## Using another fixture

In the case of say a foreign key, you may want to use the result of another
fixture when creating a new one.

Let's say that we have a `company` table with an `id` and a `name` column
and we want to add some employees to it. There are several ways to achieve
result :

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

You will declare that the _first\_employee_ fixture will need
_some\_company_ and take the object's `id` value and use this for its own
`company_id` column.

This is the most verbose syntax and it can be simplified like this :

    'second_employee' => {
        new   => 'employee',
        using => {
            first_name => 'Ford',
            last_name  => 'Prefect',
            company_id => { 'some_company' => 'id' },
        },
    },

or,

    'third_employee' => {
        new   => 'employee',
        using => {
            first_name => 'Zaphod',
            last_name  => 'Beeblebrox',
            company_id => [ 'some_company' => 'id' ],
        },
    },

_If_ the columns in both tables had the same name (ie. the `company` table had
a `company_id` column), this could have shortened as :

    'fourth_employee' => {
        new   => 'employee',
        using => {
            first_name => 'Tricia',
            last_name  => 'McMillan',
            company_id => \'some_company',
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

Note : this fixture is not yet implemented in [DBIx::Class::EasyFixture](https://metacpan.org/pod/DBIx::Class::EasyFixture).

## Using additional fixtures

After loading an object, you may need to create other objects in other tables
to have a consistent data set. Rather than calling `load()` with a long list
of fixtures, you can declare that some fixture must be loaded after the main
one. You need to write :

    'some_employee' => {
        new   => 'employee',
        using => { ... },
        next  => [qw(some_parking_spot some_desk some_gym_membership)],
    },

This will make sure that calling `$fixtures->load('some_employee')` will
also load `some_parking_spot`, `some_desk` and `some_gym_membership`.

## Group fixtures

You can also create aliases to a group of fixtures like this :

    'all_employees' => [qw(first_employee second_employee third_employee)],

Then calling `$fixture->load('all_employees')` will load the three fixtures.
If the method was called in a list context, the objects for the three employees
will be returned.

# SEE ALSO

[DBIx::Class::EasyFixture](https://metacpan.org/pod/DBIx::Class::EasyFixture) [DBIx::Class::EasyFixture::Tutorial](https://metacpan.org/pod/DBIx::Class::EasyFixture::Tutorial) 

# THANKS

Curtis "Ovid" Poe for the original module.

Everything that would work with his module but wouldn't with mine is most
certainly my fault and mine only.

# LICENSE

Copyright (C) Geraud CONTINSOUZAS.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Geraud CONTINSOUZAS <gcs at cpan.org>
