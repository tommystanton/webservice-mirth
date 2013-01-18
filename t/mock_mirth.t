#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Test::Fake::HTTPD ();
use HTTP::Request::Params ();

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
