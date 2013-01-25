package WebService::Mirth::GlobalScripts;

# ABSTRACT: Represent Mirth "global scripts"

use Moose;
use namespace::autoclean;

extends 'WebService::Mirth';

has global_scripts_dom => (
    is       => 'ro',
    isa      => 'Mojo::DOM',
    required => 1,
);

sub get_content {
    my ($self) = @_;

    my $content = $self->global_scripts_dom . ''; # (Force string context)

    return $content;
}

__PACKAGE__->meta->make_immutable;

1;
