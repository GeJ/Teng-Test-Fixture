package Teng::Test::Fixture::Definition;
use 5.008005;
use strict;
use warnings;
use utf8;

use Carp;
use Class::Accessor::Lite 0.05 (
    ro  => [qw(definition fixtures group name)],
    rw  => [qw(args next requires table)],
);
use Storable qw(dclone);


sub new { # {{{
    my $proto = shift;
    my $class = ref($proto) ? ref($proto) : $proto;
    my %args  = @_==1 ? %{$_[0]} : @_;

    foreach my $mandatory (qw(definition name fixtures)) {
        croak "Missing mandatory '$mandatory' parameter"
            unless defined $args{$mandatory};
    }

    # TODO geraud 20140312 
    # make sure that name is a string and fixtures is a hashref.

    my $self = bless {
            'name'     => $args{name},
            'fixtures' => $args{fixtures},
            'requires' => {},
        },
        $class;

    if ('ARRAY' eq ref $args{definition}) {
        my @group = $self->_check_group($args{definition});
        $self->{group} = \@group;
        $self->{definition} = {};
        return $self;
    }

    my $definition = dclone($self->{definition} = $args{definition});
    $self->_check_definition_keys($definition);

    $self->table($definition->{new});

    my %new_args;
    if (my $using = $definition->{using}) {
        foreach my $attr (keys %$using) {
            if (ref $using->{$attr}) {
                $self->_using_to_requires($attr, $using->{$attr});
            }
            else {
                $new_args{$attr} = $using->{$attr};
            }
        }
    }
    $self->args(\%new_args);

    my $name = join '.', ($self->name, $self->table);
    if (my $requires = $definition->{requires}) {
        croak("$name.requires does not appear to be a hashref")
            unless ('HASH' eq ref $requires);
        foreach my $parent (keys %$requires) {
            $self->_requires_to_requires($parent, $requires->{$parent});
        }
    }

    if (my $next = $definition->{next}) {
        my @next = $self->_check_next($next);
        $self->next(\@next);
    }

    return $self;
} # }}}

sub _check_group { # {{{
    my $self  = shift;
    my @group = @{$_[0]};

    my $name = $self->name;

    croak("Fixture '$name' defines an empty group")
        unless @group;

    if ( my @unknown = sort grep { ! $self->fixture_exists($_) } @group ) {
        croak("Fixture '$name'.group had unknown fixtures: @unknown");
    }
    return @group;
} # }}}

sub _check_definition_keys { # {{{
    my ($self, $definition) = @_;

    my $name       = $self->name;
    my %definition = %{ $definition };
    
    croak("Fixture '$name' had no keys")
        unless (keys %definition);

    delete @definition{qw/new using next requires/};
    if (my @unknown = sort keys %definition) {
        croak("Fixture '$name' had unknown keys: @unknown");
    }
} # }}}

sub _check_next { # {{{
    my $self = shift;
    my @next = ('ARRAY' eq ref($_[0])) ? @{$_[0]} : @_;
    
    my $name = $self->name;
    foreach my $next_fixture (@next) {
        croak("Fixture '$name' had an undefined element in 'next'")
            unless defined $next_fixture;
        croak("Fixture '$name' had non-string elements in 'next'")
            if (ref $next_fixture);
        croak("Fixture '$name' lists a non-existent fixture in 'next': '$next_fixture'")
            unless $self->fixture_exists($next_fixture);
    }
    return @next;
} # }}}

sub _using_to_requires { # {{{
    my ($self, $attr, $req_ref) = @_;

    my $name = $self->name;

    my $ref = ref $req_ref;
    my @require =
          ('ARRAY'  eq $ref) ? @$req_ref
        : ('HASH'   eq $ref) ? %$req_ref
        : ('SCALAR' eq $ref) ? ($$req_ref, $attr)
        : croak(
                "Unhandled reference type passed for $name.$attr: $ref"
            );
    if (@require != 2) {
        croak("$name.$attr malformed: @require");
    }

    my $parent = $require[0];
    $name = join('.', ($name, $self->table, 'requires'));
    croak("Fixture '$name' requires a non-existent fixture '$parent'")
        unless $self->fixture_exists($parent);

    $self->_add_require($parent, {'our' => $attr, 'their' => $require[1]});
} # }}}

sub _requires_to_requires { # {{{
    my ($self, $parent, $require) = @_;

    my $name = join('.', ($self->name, $self->table, 'requires'));
    croak("Fixture '$name' requires a non-existent fixture '$parent'")
        unless $self->fixture_exists($parent);

    my $ref = ref $require;

    # fixture_name => 'some_id'
    if (not $ref) {
        $self->_add_require($parent, {'our' => $require, 'their' => $require});
    }

    # fixture_name => { our => 'our_id', their => 'their_id' } or
    # fixture_name => [ {our => 'our_id', their => 'their_id'}, ... ]
    my @requires;
    if ('HASH' eq $ref) {
        push @requires, $require;
    }
    elsif ('ARRAY' eq $ref) {
        @requires = @$require;
    }
    else {
        croak("Unhandled require reference type passed for $name.$parent: $ref");
    }

    foreach my $require_data (@requires) {
        unless ('HASH' eq ref($require_data)) {
            croak("An element in $name.$parent does not appear to be a hashref");
        }
        my %require = %{ $require_data };
        my $our = (exists $require{'our'})
            ? delete($require{'our'})
            : croak("'$name' requires 'our'");
        my $their = ( exists $require{their} )
            ? delete($require{'their'})
            : croak("'$name' requires 'their'");
        if (my @unknown = sort keys %require) {
            croak("'$name' had bad keys: @unknown");
        }
        $self->_add_require($parent, {'our' => $our, 'their' => $their});
    }
} # }}}

sub _add_require { # {{{
    my ($self, $parent, $methods) = @_;

    if (exists $self->{requires}->{$parent}) {
        push @{$self->{requires}->{$parent}}, $methods;
    }
    else {
        $self->{requires}->{$parent} = [$methods];
    }
} # }}}

sub fixture_exists { exists $_[0]->fixtures()->{$_[1]} }

# Compatibility with DBIC::EasyFixture
sub resultset_class  { $_[0]->table }
sub constructor_data { $_[0]->args }

# Fixture dependency resolution
sub required_fixtures { sort keys %{ $_[0]->requires } }

1;

__END__

=encoding utf-8

=head1 NAME

Teng::Test::Fixture::Definition

=head1 DESCRIPTION

This module is used internally by L<Teng::Test::Fixture> and probably should
not be called directly.

=head1 LICENSE

Copyright (C) Geraud CONTINSOUZAS.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Geraud CONTINSOUZAS E<lt>gcs at cpan.orgE<gt>

=cut

