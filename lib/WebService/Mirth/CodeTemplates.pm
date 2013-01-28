package WebService::Mirth::CodeTemplates;

# ABSTRACT: Represent Mirth "code templates"

use Moose;
use namespace::autoclean;

extends 'WebService::Mirth';

has code_templates_dom => (
    is       => 'ro',
    isa      => 'Mojo::DOM',
    required => 1,
);

sub get_content {
    my ($self) = @_;

    my $content = $self->code_templates_dom . ''; # (Force string context)

    return $content;
}

__PACKAGE__->meta->make_immutable;

1;
