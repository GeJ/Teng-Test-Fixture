package Teng::Test::Fixture::DependencyResolver;
use 5.008005;
use strict;
use warnings;
use utf8;

use Carp;
use Class::Accessor::Lite 0.05 (
        'rw' => [qw(_graph _unresolved resolved)],
    );

sub new {
    my $proto = shift;
    my $class = (ref($proto)) ? ref($proto) : $proto;
    my $self  = bless {
            _graph      => {},
            _unresolved => [],
            resolved    => [],
        },
        $class;
    return $self;
}

sub add_node {
    my $self = shift;
    my $node = shift;
    my %args = @_==1 ? %{$_[0]} : @_;

    my (@requires, @wants);

    if (exists $args{requires}) {
        my $ref = ref $args{requires};
        @requires
            = ('ARRAY' eq $ref) ? @{$args{requires}}
            : (''      eq $ref) ? ($args{requires})
            : croak("Unhandled reference type passed for requires: $ref");
    }

    if (exists $args{wants}) {
        my $ref = ref $args{wants};
        @wants
            = ('ARRAY' eq $ref) ? @{$args{wants}}
            : (''      eq $ref) ? ($args{wants})
            : croak("Unhandled reference type passed for wants: $ref");
    }

    if (exists $self->_graph->{$node}) {
        @requires = (@{$self->_graph->{$node}->{requires}}, @requires);
        @wants    = (@{$self->_graph->{$node}->{wants}},    @wants);
    }

    $self->_graph->{$node} = {requires => [ _uniq(@requires) ], wants => [ _uniq(@wants) ]};
}

sub _uniq {
    return sort keys %{{ map { ($_ => 1) } @_ }};
}

sub resolve {
    my ($self, $node) = @_;
    
    # Clean before processing
    $self->_unresolved([]);
    $self->resolved([]);

    $self->_resolve($node);
    return @{$self->resolved};
}

sub _resolve {
    my ($self, $node) = @_;

    # A very simple algorithm. It will stop on the first dependency circle
    # it'll find. This could and should be improved.

    push @{ $self->{_unresolved} }, $node;

    foreach my $edge (@{$self->_graph->{$node}->{requires}}) {
        if (not grep{ $_ eq $edge } @{$self->resolved}) {
            if (grep{ $_ eq $edge } @{$self->_unresolved}) {
                croak("Circular reference detected in 'requires': $node -> $edge")
            }
            $self->_resolve($edge);
        }
    }

    push @{$self->{resolved}}, $node;
    # At this point the fixture is loaded and is available to the 'wants' one
    # so remove it from _unresolved.
    $self->_remove_unresolved($node);

    foreach my $edge (@{$self->_graph->{$node}->{wants}}) {
        if (not grep{ $_ eq $edge } @{$self->resolved}) {
            if (grep{ $_ eq $edge } @{$self->_unresolved}) {
                croak("Circular reference detected in 'wants': $node -> $edge")
            }
            $self->_resolve($edge);
        }
    }
}

sub _remove_unresolved {
    my ($self, $node) = @_;
    my @node_less = grep { $_ ne $node } @{$self->_unresolved};
    $self->_unresolved(\@node_less);
}

1;

__END__
