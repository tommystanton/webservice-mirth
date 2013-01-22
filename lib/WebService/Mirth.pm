package WebService::Mirth;

# ABSTRACT: Interact with a Mirth Connect server via REST

use Moose;
use namespace::autoclean;

use Mojo::URL ();
use Mojo::UserAgent ();

use Log::Minimal qw( debugf warnf croakff );

use aliased 'WebService::Mirth::Channel' => 'Channel', ();

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
        _handle_tx_error( [ $tx->error ] );
    }

    $tx->success ? return 1 : return 0;
}

# (Content-Type will probably be application/xml;charset=UTF-8)
sub get_channel {
    my ( $self, $channel_name ) = @_;

    my $url = $self->base_url->clone->path('/channels');

    my $tx = $self->_ua->post_form( $url,
        {   op      => 'getChannel',
            channel => '<null/>',
        }
    );

    if ( my $response = $tx->success ) {
        # XXX Hack: Append XML declaration to ensure that XML semantics
        # are turned on when the Mojo::DOM object is created (via
        # Mojo::Message::dom())
        my $body = $response->body;
        $body = qq{<?xml version="1.0"?>\n$body};
        $response->body($body);

        my $channels = $response->dom;

=begin comment

Find the "name" node of the channel desired, then get its parent
("channel").  To find a channel named "quux", find the name node
containing "quux", then get its parent (the channel node):

  <channel>
      <id>dc444818-9b64-42db-9d59-3d478c9ea3ef</id>
      <name>quux</name>
      <description>This channel feeds.</description>
  ...
  </channel>

=end comment

=cut

        my $channel_name_dom =
            $channels->find('channel > name')
                     ->first( sub { $_->text eq $channel_name } );

        my $channel_dom;
        if ( defined $channel_name_dom ) {
            $channel_dom = $channel_name_dom->parent;
        }
        else {
            warnf( 'Channel "%s" does not exist', $channel_name );
            return undef;
        }

        my $channel = Channel->new( { channel_dom => $channel_dom } );

        return $channel;
    }
    else {
        _handle_tx_error( [ $tx->error ] );
    }
}

sub logout {
    my ($self) = @_;

    my $url = $self->base_url->clone->path('/users');

    debugf('Logging out');
    my $tx = $self->_ua->post_form( $url, { op => 'logout' } );

    if ( my $response = $tx->success ) {
    }
    else {
        _handle_tx_error( [ $tx->error ] );
    }

    $tx->success ? return 1 : return 0;
}

sub _handle_tx_error {
    my ( $message, $code ) = @{ $_[0] };
    croakff( 'Failed with HTTP code %s: %s', $code, $message );
}

__PACKAGE__->meta->make_immutable;

1;
