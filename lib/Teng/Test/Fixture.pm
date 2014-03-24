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

Teng::Test::Fixture - Manage your Teng test data.

=head1 SYNOPSIS

    use Teng::Test::Fixture;

=head1 DESCRIPTION

Teng::Test::Fixture is a port of Ovid's DBIx::Class::EasyFixture for Teng

=head1 LICENSE

Copyright (C) Geraud CONTINSOUZAS.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Geraud CONTINSOUZAS E<lt>gcs at cpan.orgE<gt>

=cut

