#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::XML;
use Test::Warn;
use Test::Fatal;

use Test::Fake::HTTPD 0.06 ();
use Class::Monkey qw( Test::Fake::HTTPD );

use HTTP::Request::Params ();
use Path::Class ();

my $t_lib_dir = Path::Class::Dir->new('t/lib/mock_mirth/');

# XXX Monkey patch for HTTPS certs/ location:
# mostly copy and paste the original method :-/
override 'run' => sub {
    my $cert_dir = $t_lib_dir->subdir('certs');

    my %certs_args = (
        SSL_key_file  => $cert_dir->file('server-key.pem')->stringify,
        SSL_cert_file => $cert_dir->file('server-cert.pem')->stringify,
    );

    eval <<'!STUFFY!FUNK!';
    my ($self, $app) = @_;

    $self->{server} = Test::TCP->new(
        code => sub {
            my $port = shift;

            my $d;
            for (1..10) {
                $d = $self->_daemon_class->new(
                    %certs_args, # XXX Monkey patch
                    LocalAddr => '127.0.0.1',
                    LocalPort => $port,
                    Timeout   => $self->{timeout},
                    Proto     => 'tcp',
                    Listen    => $self->{listen},
                    ($self->_is_win32 ? () : (ReuseAddr => 1)),
                ) and last;
                Time::HiRes::sleep(0.1);
            }

            croak("Can't accepted on 127.0.0.1:$port") unless $d;

            $d->accept; # wait for port check from parent process

            while (my $c = $d->accept) {
                while (my $req = $c->get_request) {
                    my $res = $self->_to_http_res($app->($req));
                    $c->send_response($res);
                }
                $c->close;
                undef $c;
            }
        },
        ($self->{port} ? (port => $self->{port}) : ()),
    );

    weaken($self);
    $self;
!STUFFY!FUNK!
}, qw( Test::Fake::HTTPD );

# Mock a Mirth Connect server
my $httpd = Test::Fake::HTTPD->new( scheme => 'https' );
$httpd->run( sub {
    my $params = HTTP::Request::Params->new( { req => $_[0] } )->params;

    my $response;
    if ( $params->{op} eq 'login' ) {
        my ( $username, $password )
            = map { $params->{$_} } qw( username password );

        my $is_auth =
            $username eq 'admin' && $password eq 'admin' ? 1 : 0;

        # TODO Return a cookie

        if ($is_auth) {
            $response = [
                200,
                [ 'Content-Type' => 'text/plain' ],
                [ 'true' ]
            ];
        }
        else {
            $response = [ 500, [], [] ];
        }
    }
    elsif ( $params->{op} eq 'getChannel' ) {
        my $foobar_xml = _get_channel_fixture('foobar');
        my $quux_xml   = _get_channel_fixture('quux');

        my $channels_xml = <<"END_XML";
<list>
$foobar_xml
$quux_xml
</list>
END_XML

        $response = [
            200,
            [ 'Content-Type' => 'application/xml' ],
            [ $channels_xml ]
        ];
    }
    elsif ( $params->{op} eq 'logout' ) {
        $response = [ 200, [], [] ];
    }

    return $response;
});

ok( defined $httpd, 'Got a test HTTP server (HTTPS)' );

my $class = 'WebService::Mirth';
use_ok($class);

my ( $server, $port ) = split /:/, $httpd->host_port;

{
    my $mirth = $class->new(
        server   => $server,
        port     => $port,
        version  => '42',
        username => 'admin',
        password => 'incorrect',
    );

    like(
        exception { $mirth->login; },
        qr/failed.*?HTTP.*?500/i,
        'Login with bad credentials causes exception'
    );
}

my $mirth = $class->new(
    server   => $server, # XXX FQDN needed for cookies to work
    port     => $port,
    version  => '42',
    username => 'admin',
    password => 'admin',
);

ok $mirth->login, 'Login with good credentials';

{
    my $channel;

    warning_like
        { $channel = $mirth->get_channel('baz'); }
        qr/does not exist/,
        'Got warning about invalid channel not existing';

    ok( ! defined $channel, 'undef returned for invalid channel' );
}

{
    my $name = 'quux';
    my $id   = 'dc444818-9b64-42db-9d59-3d478c9ea3ef';

    my $channel = $mirth->get_channel($name);
    ok( defined $channel, 'Got a value for a valid channel' );

    is $channel->name, $name, 'Parsed name is correct';
    is $channel->id,   $id,   'Parsed ID is correct';

    my $content = $channel->get_content;
    is_xml(
        $content, _get_channel_fixture($name),
        "XML received for $name is correct"
    );
}

ok $mirth->logout, 'Logout';

sub _get_channel_fixture {
    my ($channel_to_get) = @_;

    my $channels_dir = $t_lib_dir->subdir('channels');
    my $channel      = $channels_dir->file("${channel_to_get}.xml");

    my @lines = $channel->slurp;
    my $channel_xml = join '', @lines;

    return $channel_xml;
}

done_testing;
