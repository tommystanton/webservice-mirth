package WebService::Mirth;

# ABSTRACT: Interact with a Mirth Connect server via REST

use Moose;
use namespace::autoclean;

use MooseX::Types::Path::Class::MoreCoercions qw( Dir );
use MooseX::Params::Validate qw( validated_list );

use Mojo::URL ();
use Mojo::UserAgent ();

use Path::Class ();
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
    default  => '0.0.0', # "Use 0.0.0 to ignore this property."
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

has channels_dom => (
    is         => 'ro',
    isa        => 'Mojo::DOM',
    lazy_build => 1,
);

sub _build_channels_dom {
    my ($self) = @_;

    my $url = $self->base_url->clone->path('/channels');

    my $tx = $self->_ua->post_form( $url,
        {   op      => 'getChannel',
            channel => '<null/>',
        }
    );

    # (Content-Type will probably be application/xml;charset=UTF-8)
    if ( my $response = $tx->success ) {
        # XXX Hack: Append XML declaration to ensure that XML semantics
        # are turned on when the Mojo::DOM object is created (via
        # Mojo::Message::dom())
        my $body = $response->body;
        $body = qq{<?xml version="1.0"?>\n$body};
        $response->body($body);

        my $channels_dom = $response->dom;

        return $channels_dom;
    }
    else {
        _handle_tx_error( [ $tx->error ] );
    }
}

has channel_list => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
);

sub _build_channel_list {
    my ($self) = @_;

    my @channel_names = @{
        $self->channels_dom->find( 'channel > name' )
                           ->map ( sub { $_->text } )
    };

    my %channel_list;
    foreach my $name (@channel_names) {
        my $channel = $self->get_channel($name);
        my $id      = $channel->id;

        $channel_list{$name} = $id;
    }

    return \%channel_list;
}

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

sub get_channel {
    my ( $self, $channel_name ) = @_;

    my $channel_dom = $self->_get_channel_dom($channel_name);

    if ( not defined $channel_dom ) {
        return undef;
    }

    my $channel = Channel->new( { channel_dom => $channel_dom } );

    return $channel;
}

sub _get_channel_dom {
    my ( $self, $channel_name ) = @_;

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
        $self->channels_dom
             ->find ( 'channel > name' )
             ->first( sub { $_->text eq $channel_name } );

    my $channel_dom;
    if ( defined $channel_name_dom ) {
        $channel_dom = $channel_name_dom->parent;
    }
    else {
        warnf( 'Channel "%s" does not exist', $channel_name );
        return undef;
    }

    return $channel_dom;
}

sub export_channels {
    my $self = shift;
    my ($output_dir) = validated_list(
        \@_,
        to_dir => { isa => Dir, coerce => 1 },
    );

    foreach my $channel_name ( sort keys %{ $self->channel_list } ) {
        my $channel = $self->get_channel($channel_name);

        my $filename = sprintf '%s.xml', $channel->name;
        my $output_file = $output_dir->file($filename);

        my $content = $channel->get_content;

        debugf(
            'Exporting "%s" channel: %s',
            $channel->name, $output_file->stringify
        );
        $output_file->spew($content);
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

    croakff(
        'Failed with HTTP code %s: %s',
        $code || 'N/A',
        $message
    );
}

__PACKAGE__->meta->make_immutable;

1;
