package WebService::Mirth::Channel;

# ABSTRACT: Represent a Mirth channel

use Moose;
use namespace::autoclean;

extends 'WebService::Mirth';

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

sub get_content {
    my ($self) = @_;

    my $content = $self->channel_dom . ''; # (Force string context)

    return $content;
}

__PACKAGE__->meta->make_immutable;

1;
