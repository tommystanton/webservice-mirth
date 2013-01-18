#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Test::Fake::HTTPD 0.06 ();
use Class::Monkey qw( Test::Fake::HTTPD );

use HTTP::Request::Params ();

# XXX Monkey patch for HTTPS certs/ location:
# mostly copy and paste the original method :-/
override 'run' => sub {
    use Scalar::Util qw( weaken );
    use Time::HiRes ();
    use Carp qw(croak);

    my $cert_path = 't/lib/mock_mirth/certs';

    my %certs_args = (
        SSL_key_file  => "${cert_path}/server-key.pem",
        SSL_cert_file => "${cert_path}/server-cert.pem",
    );

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
}, qw( Test::Fake::HTTPD );

# Mock a Mirth Connect server
my $httpd = Test::Fake::HTTPD->new( scheme => 'https' );
$httpd->run( sub {
    my $params = HTTP::Request::Params->new( { req => $_[0] } )->params;

    my $response;
    if ( $params->{op} eq 'login' ) {
        # TODO Return a cookie
        $response = [
            200,
            [ 'Content-Type' => 'text/plain' ],
            [ 'true' ]
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

my $mirth = $class->new(
    server   => 'localhost.localdomain',
    port     => $httpd->port,
    version  => '42',
    username => 'admin',
    password => 'admin',
);

ok $mirth->login,  'Login';
ok $mirth->logout, 'Logout';

done_testing;
