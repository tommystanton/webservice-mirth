package WebService::Mirth::Channel;

# ABSTRACT: Represent a Mirth channel

use Moose;
use namespace::autoclean;

extends 'WebService::Mirth';

use Moose::Util::TypeConstraints qw( enum );

has channel_dom => (
    is       => 'ro',
    isa      => 'Mojo::DOM',
    required => 1,
);

has name => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub { $_[0]->channel_dom->at('name')->text },
);

has id => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub { $_[0]->channel_dom->at('id')->text },
);

# TODO Use MooseX::RemoteHelper?  This is actually a Bool.
has enabled => (
    is      => 'rw',
    isa     => enum( [qw( true false )] ),
    lazy    => 1,
    default => sub { $_[0]->channel_dom->at('enabled')->text },
);

sub get_content {
    my ($self) = @_;

    my $content = $self->channel_dom . ''; # (Force string context)

    return $content;
}

__PACKAGE__->meta->make_immutable;

1;
