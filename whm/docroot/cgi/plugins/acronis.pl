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
use constant DATA_PATH => '/usr/local/cpanel/3rdparty/etc/acronis/';
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
			serverurl => undef,
			username => undef,
			password => undef,
			cookies => undef,
			access_token => undef,
			planid => undef,
			encrptpass => undef
		};
    my $prm    = Cpanel::Form::Param->new();
    my $conf;
    {
        local $/;
        open( my $fh, '<',
            &DATA_PATH . 'acronisbackupwhm.conf' );
        $conf = JSON::decode_json(<$fh>);
    }

    if ( !Whostmgr::ACLS::hasroot() ) {
        print "Content-type: text/plain\r\n\r\n";
        print "Access Denied";
        exit;
    }

	if((defined $prm->param('step')) && ($prm->param('step') eq "step1")){
		$acronisData->{url} = $prm->param('HostName');
		$acronisData->{username} = $prm->param('UserName');
		$acronisData->{password} = $prm->param('UserPass');		 
		 
		 print "Content-type: application/json\r\n\r\n";
		 if(validateUserHost($acronisData, 0, $conf) eq ''){

			print "{\"status\":200, \"data\":".getBackUpPlans($acronisData)."}\n";
			exit;
		 }
		print "{\"status\":200,\"error\":\"there was an error\"}\n";
		exit;
	}
	elsif((defined $prm->param('step')) && ($prm->param('step') eq "step2")){
		$acronisData->{url} = $prm->param('HostName');
		$acronisData->{username} = $prm->param('UserName');
		$acronisData->{password} = $prm->param('UserPass');	
		$acronisData->{planid} = $prm->param('BackUpPlan');
		$acronisData->{encrptpass} = $prm->param('ServerEncrypt');	
		
		if(validateUserHost($acronisData) eq ''){
			print "{\"status\":200, \"data\":".getBackUpPlans($acronisData)."}\n";
			exit;
		 }
		 
		print "{\"status\":200,\"error\":\"there was an error\"}\n";
		exit;
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
	my $uri = URI->new($_[0]->{url} . &API_URI);
	$uri->path($uri->path . 'accounts/');
	$uri->query_form('login' => $_[0]->{username});
	
	my $response = $ua->get($uri);
	die $response->message() unless ($response->is_success());
	
	my $content = JSON::XS->new->utf8->decode($response->content());
	$_[0]->{serverurl} = $content->{server_url};

	$uri = URI->new($_[0]->{serverurl} . &API_URI);
	$uri->path($uri->path . '/login/');;
	$response = $ua->post($uri, Content_Type => &CONTENT_TYPE, 'Content' => JSON::XS->new->utf8->encode({username => $_[0]->{username}, password => $_[0]->{password}}));
	die $response->message() unless ($response->is_success());
	
	$uri = URI->new($_[0]->{serverurl} . &API_URI);
	$uri->path($uri->path . '/groups/self/backupconsole');;
	$response = $ua->get($uri);
	die $response->message() unless ($response->is_success());

	$content = JSON::XS->new->utf8->decode($response->content());
	$_[0]->{access_token} = $content->{token};
	$_[0]->{serverurl} = $content->{host};
	
	$uri = URI->new($_[0]->{serverurl});
	$uri->path($uri->path . '/api/remote_connection');;
	$response = $ua->post($uri, Content_Type => &CONTENT_TYPE, 'Content' => JSON::XS->new->utf8->encode({access_token => $_[0]->{access_token}}));
	
	die $response->message() unless ($response->is_success());
	
	$_[0]->{cookies} = $ua->cookie_jar;
	
	$_[0]->{cookies}->save(&DATA_PATH . 'whmapi.cookie');

	return 1;
}

sub getBackUpPlans {
	
	if ($_[0]->{cookies}) {
		my $jar = HTTP::Cookies->new(file => $_[0]->{cookies});
		my @urls = keys %{$jar->{COOKIES}};
	}
	else{
		if(getCookie($_[0]) != 1){
			return '';
		}		
	}
	
	my $plans = JSON::decode_json(get($_[0], 0, '/api/ams/backup/plans')->content())->{data};
	my @plan_names = map {{ id => $_->{id}, name => $_->{name}}} @$plans;

	
	
	return JSON::encode_json(\@plan_names);

}

sub get {


	my $uri = undef;
	if($_[1] == 1){
		$uri = URI->new($_[0]->{serverurl} . &API_URI. $_[2]);
	}
	else{	
		$uri = URI->new($_[0]->{serverurl} . $_[2]);
	}
	$uri->path($uri->path);

	my $headers = HTTP::Headers->new('Content-Type' => &CONTENT_TYPE);
	my $ua = LWP::UserAgent->new(
		cookie_jar => $_[0]->{cookies},
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
	
	if ( $_[0]->{password} eq '' && $conf.pass eq '') {
		
		return "password is empty";
	}
	
	if($_[1] == 1){
		if ( $_[0]->{password} eq '' && $conf.pass eq '') {
			
			return "password is empty";
		}
		
	}
	

	return "";
}

1;