#!/usr/local/cpanel/3rdparty/bin/perl
#Need to add apcache 2.0 license
#
#

BEGIN { unshift @INC, '/usr/local/cpanel'; }

package Acronis;

use strict;
use warnings;

use Cpanel::Form::Param     ();
use Cpanel::Template        ();
use JSON                    ();
use Whostmgr::ACLS          ();
use Whostmgr::HTMLInterface ();
use LWP::UserAgent          ();
use URI                     ();
use HTTP::Headers           ();
use HTTP::Cookies           ();
use HTTP::Request::Common   ();

# TODO: No no no plz and thanks <3
use Data::Dumper;

use constant API_URI      => '/api/1/';
use constant DATA_PATH    => '/usr/local/cpanel/3rdparty/etc/acronis/';
use constant CONTENT_TYPE => 'application/json';

Whostmgr::ACLS::init_acls();

sub getCookie {

    eval {
        my $headers = HTTP::Headers->new( 'Content-Type' => &CONTENT_TYPE );
        my $ua = LWP::UserAgent->new(
            cookie_jar      => {},
            default_headers => $headers
        );
        my $uri = URI->new( $_[0]->{url} . &API_URI );
        $uri->path( $uri->path . 'accounts/' );
        $uri->query_form( 'login' => $_[0]->{username} );

        my $response = $ua->get($uri);
        die $response->message() unless ( $response->is_success() );

        my $content = JSON::XS->new->utf8->decode( $response->content() );
        $_[0]->{serverurl} = $content->{server_url};

        $uri = URI->new( $_[0]->{serverurl} . &API_URI );
        $uri->path( $uri->path . '/login/' );
        $response = $ua->post(
            $uri,
            Content_Type => &CONTENT_TYPE,
            'Content'    => JSON::XS->new->utf8->encode(
                {
                    username => $_[0]->{username},
                    password => $_[0]->{password}
                }
            )
         );
        die $response->message() unless ( $response->is_success() );

        $uri = URI->new( $_[0]->{serverurl} . &API_URI );
        $uri->path( $uri->path . '/groups/self/backupconsole' );
        $response = $ua->get($uri);
        die $response->message() unless ( $response->is_success() );

        $content = JSON::XS->new->utf8->decode( $response->content() );
        $_[0]->{access_token} = $content->{token};
        $_[0]->{serverurl}    = $content->{host};

        $uri = URI->new( $_[0]->{serverurl} );
        $uri->path( $uri->path . '/api/remote_connection' );
        $response = $ua->post(
            $uri,
            Content_Type => &CONTENT_TYPE,
            'Content'    => JSON::XS->new->utf8->encode(
                { access_token => $_[0]->{access_token} }
            )
        );

        die $response->message() unless ( $response->is_success() );

        $_[0]->{cookies} = $ua->cookie_jar;

        $_[0]->{cookies}->save( &DATA_PATH . 'whmapi.cookie' );

        return '';
    };

    if ($@) {
        return $@;
    }
}

sub getBackUpPlans {

    my @plan_names;

    if ( $_[0]->{cookies} ) {
        my $jar = HTTP::Cookies->new( file => $_[0]->{cookies} );
        my @urls = keys %{ $jar->{COOKIES} };
    }
    else {
        my $cookieResponse = getCookie( $_[0] );
        if ( $cookieResponse ne '' ) {
            return { status => 500, msg => $cookieResponse };
        }
    }

    my $plans =
      JSON::decode_json( get( $_[0], 0, '/api/ams/backup/plans' )->content() )
      ->{data};
    @plan_names = map { { id => $_->{id}, name => $_->{name} } } @$plans;

    return { status => 200, data => \@plan_names };

}

sub get {

    my $uri = undef;
    if ( $_[1] == 1 ) {
        $uri = URI->new( $_[0]->{serverurl} . &API_URI . $_[2] );
    }
    else {
        $uri = URI->new( $_[0]->{serverurl} . $_[2] );
    }
    $uri->path( $uri->path );

    my $headers = HTTP::Headers->new( 'Content-Type' => &CONTENT_TYPE );
    my $ua = LWP::UserAgent->new(
        cookie_jar      => $_[0]->{cookies},
        default_headers => $headers
    );
    my $response = $ua->get($uri);

    return $response;
}

sub validateUserHost {

    if ( $_[0]->{url} eq '' ) {
        return "url is empty";
    }

    if ( $_[0]->{username} eq '' ) {

        return "username is empty";
    }

    if ( $_[0]->{password} eq '' && $_[2]->{pass} eq '' ) {

        return "password is empty";
    }

    if ( $_[1] == 1 ) {
        if ( $_[0]->{password} eq '' && $_[2]->{pass} eq '' ) {

            return "password is empty";
        }

    }

    return "";
}

1;


