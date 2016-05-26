#!/usr/local/cpanel/3rdparty/bin/perl
#Need to add apcache 2.0 license
#
#

BEGIN { unshift @INC, '/usr/local/cpanel'; }

use strict;
use warnings;

# Commented out stuff I"m pretty sure we won't need
# but not 100%, so it's just commented out

# use Cpanel::App             ();
# use Cpanel::Config          ();
# use Cpanel::Config::Httpd   ();
# use Cpanel::Encoder::Tiny   ();
# use Cpanel::FileUtils       ();
use Cpanel::Form::Param     ();
# use Cpanel::Locale          ('lh');
# use Cpanel::SafeRun         ();
use Cpanel::Template        ();
use JSON                    ();
use Whostmgr::ACLS          ();
use Whostmgr::HTMLInterface ();

use LWP::UserAgent;
use URI;
use HTTP::Headers;
use HTTP::Cookies;
use HTTP::Request::Common;
use Data::Dumper;

use constant API_URI => '/api/1/';
use constant CONTENT_TYPE => 'application/json';


Whostmgr::ACLS::init_acls();

if ( !caller() ) {
    my $result = __PACKAGE__->run();
    if ( !$result ) {
        exit 1;
    }
}

sub run {
	my $acronisData = {
			url => undef,
			username => undef,
			password => undef,
			cookies => undef,	
			@_
		};
    my $prm    = Cpanel::Form::Param->new();
    my $conf;
    {
        local $/;
        open( my $fh, '<',
            '/usr/local/cpanel/3rdparty/etc/acronis/acronisbackupwhm.conf' );
        $conf = JSON::decode_json(<$fh>);
    }

    if ( !Whostmgr::ACLS::hasroot() ) {
        print "Content-type: text/plain\r\n\r\n";
        print "Access Denied";
        exit;
    }
	
	if($prm.param('step') == "step1"){
		$acronisData.url = $prm.param('HostName');
		$acronisData.username = $prm.param('UserName');
		$acronisData.password = $prm.param('password');
	
	}

    print "Content-type: text/html\r\n\r\n";
    Cpanel::Template::process_template(
        'whostmgr',
        {
            'template_file' => 'acronisbackup.tmpl',
            'data'          => {
                'version' => "Acronis Backup Manager .01",
            },
            'form'    => $prm,
            'options' => $conf,
        },
    );

    exit;
}

sub getCookie {

	my $headers = HTTP::Headers->new('Content-Type' => &CONTENT_TYPE);
	my $ua = LWP::UserAgent->new(
		cookie_jar => {},
		default_headers => $headers
	);
	my $uri = URI->new($_[0]->url . &API_URI);
	$uri->path($uri->path . 'accounts/');
	$uri->query_form('login' => $_[0]->username);
	
	my $response = $ua->get($uri);
	die $response->message() unless ($response->is_success());
	
	
	my $content = JSON::XS->new->utf8->decode($response->content());
	my $server_url = $content->{server_url};

	$uri = URI->new($server_url . &API_URI);
	$uri->path($uri->path . '/login/');;
	$response = $ua->post($uri, Content_Type => &CONTENT_TYPE, 'Content' => JSON::XS->new->utf8->encode({username => $_[0]->username, password => $_[0]->password}));
	die $response->message() unless ($response->is_success());

	return 1;
}

sub getBackUpPlans {
	
	if ($_[0]->{cookies}) {
		my $jar = HTTP::Cookies->new(file => $_[0]->{cookies});
		my @urls = keys %{$jar->{COOKIES}};
	}

	

	return 1;
}

sub validateUserHost {

	if ( $_[0].url ne '' ) {
		return 0;
	}
	
	if ( $_[0].username ne '' ) {
		return 0;
	}
	
	if ( $_[0].password ne '' ) {
		return 0;
	}
	

	return 1;
}

1;