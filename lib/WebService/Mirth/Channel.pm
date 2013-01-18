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

sub get_content {
    my ($self) = @_;

    my $content = $self->channel_dom . ''; # (Force string context)

    return $content;
}

__PACKAGE__->meta->make_immutable;

1;
