package WebService::Mirth;

# ABSTRACT: Interact with a Mirth Connect server via REST

use Moose;
use namespace::autoclean;

use Mojo::URL ();
use Mojo::UserAgent ();

use Log::Minimal qw( debugf croakff );

has server => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

# "Administrator Port"
has port => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
    #default  => 8443,
);

has version => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has username => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has password => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has base_url => (
    is         => 'ro',
    isa        => 'Mojo::URL',
    lazy_build => 1,
);

sub _build_base_url {
    my ($self) = @_;

    my $base_url = Mojo::URL->new;

    $base_url->scheme('https');
    $base_url->host( $self->server );
    $base_url->port( $self->port );

    return $base_url;
}

has _ua => (
    is      => 'rw',
    isa     => 'Mojo::UserAgent',
    lazy    => 1,
    default => sub { Mojo::UserAgent->new },
);

sub login {
    my ($self) = @_;

    my $url = $self->base_url->clone->path('/users');

    debugf( 'Logging in as "%s" at %s', $self->username, $url );
    my $tx = $self->_ua->post_form( $url,
        {   op       => 'login',
            username => $self->username,
            password => $self->password,
            version  => $self->version,
        }
    );

=begin comment

Mirth Connect version 2.1.1.5490 will return:

true

...with Content-Type text/plain;charset=ISO-8859-1 .

Mirth Connect version 2.2.1.5861 will return:

  <com.mirth.connect.model.LoginStatus>
    <status>SUCCESS</status>
    <message></message>
  </com.mirth.connect.model.LoginStatus>

...with Content-Type text/plain;charset=UTF-8 .

=end comment

=cut

    if ( my $response = $tx->success ) {
    }
    else {
        my ( $message, $code ) = $tx->error;
        croakff( 'Login failed with HTTP code %s: %s', $code, $message );
    }

    $tx->success ? return 1 : return 0;
}

sub logout {
    my ($self) = @_;

    my $url = $self->base_url->clone->path('/users');

    debugf('Logging out');
    my $tx = $self->_ua->post_form( $url, { op => 'logout' } );

    if ( my $response = $tx->success ) {
    }
    else {
        my ( $message, $code ) = $tx->error;
        croakff( 'Logout failed with HTTP code %s: %s', $code, $message );
    }

    $tx->success ? return 1 : return 0;
}

__PACKAGE__->meta->make_immutable;

1;
