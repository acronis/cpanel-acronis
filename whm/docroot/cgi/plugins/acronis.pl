#!/usr/local/cpanel/3rdparty/bin/perl
#Need to add apcache 2.0 license
#
#

# Why do we have to add /var/cpanel/perl5/lib to @INC? It should already be there...
BEGIN { unshift @INC, '/usr/local/cpanel', '/var/cpanel/perl5/lib'; }

use strict;
use warnings;

use Acronis ();

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
use Socket;
use Sys::Hostname;

# TODO: No no no plz and thanks <3
use Data::Dumper;


use constant API_URI      => '/api/1/';
use constant DATA_PATH    => '/usr/local/cpanel/3rdparty/etc/acronis/';
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
        url          => undef,
        serverurl    => undef,
        username     => undef,
        password     => undef,
        cookies      => undef,
        access_token => undef,
        planid       => undef,
        encrptpass   => undef
    };
    my $prm = Cpanel::Form::Param->new();
    my $conf;
    {
        local $/;
        open( my $fh, '<', &DATA_PATH . 'acronisbackupwhm.conf' );
        $conf = JSON::decode_json(<$fh>);
    }

    if ( !Whostmgr::ACLS::hasroot() ) {
        print "Content-type: text/plain\r\n\r\n";
        print "Access Denied";
        exit;
    }

    if ( ( defined $prm->param('step') ) ) {
        print "Content-type: application/json\r\n\r\n";
        if ( ( $prm->param('step') eq "step1" ) ) {
            $acronisData->{url}      = $prm->param('HostName');
            $acronisData->{username} = $prm->param('UserName');
            $acronisData->{password} = $prm->param('UserPass');

            if ( Acronis::validateUserHost( $acronisData, 0, $conf ) eq '' ) {
                my $planData = Acronis::getBackUpPlans($acronisData);
                if ( $planData->{status} != 200 ) {
                    print JSON::encode_json($planData) . "\n";
                    exit;
                }
                print "{\"status\":200, \"data\":"
                  . JSON::encode_json( $planData->{data} ) . "}\n";
                exit;
            }
            print "{\"status\":500,\"msg\":\"there was an error\"}\n";
            exit;
        }
        elsif ( ( $prm->param('step') eq "step2" ) ) {
            $acronisData->{url}      = $prm->param('HostName');
            $acronisData->{username} = $prm->param('UserName');
            if ( $prm->param('UserPass') ) {
                $acronisData->{password} = $prm->param('UserPass');
            }
            $acronisData->{planid}     = $prm->param('BackUpPlan');
            $acronisData->{encrptpass} = $prm->param('ServerEncrypt');

            if ( Acronis::validateUserHost( $acronisData, 1,, $conf ) eq '' ) {
                $conf->{host} = $acronisData->{url};
                $conf->{user} = $acronisData->{username};
                if ( $acronisData->{password} ) {
                    $conf->{pass} = $acronisData->{password};
                }
                $conf->{plan}       = $acronisData->{planid};
                $conf->{encryption} = $acronisData->{encrptpass};

                my $host = hostname();
                my $address =
                  inet_ntoa( scalar gethostbyname( $host || 'localhost' ) );

                 my @servers = @{ Acronis::get_machines($acronisData) };

                foreach my $server (@servers) {
                    if ( grep { $_ eq $address } @{ $server->{ip} } ) {
                        $conf->{serverid} = $server->{id};
                        last;
                    }
                }

                if( $conf->{serverid}){
                        open my $fh, ">", &DATA_PATH . 'acronisbackupwhm.conf';
                        print $fh JSON::encode_json($conf);
                        close $fh;

                        print qq[{"status":200, "data":"saved"}\n];
                        exit;
                }
                print qq[{"status":500,"msg":"Could not find server id"}\n];
                exit;

            }

            print qq[{"status":500,"msg":"there was an error"}\n];
            exit;
        }
        print qq[{"status":500,"msg":"Invalid Step"}\n];
        exit;
    }

    print "Content-type: text/html\r\n\r\n";

    my $planOptions = undef;
    if ( $conf->{plan} ) {
        $acronisData->{url}      = $conf->{host};
        $acronisData->{username} = $conf->{user};
        $acronisData->{password} = $conf->{pass};

        my $planData = Acronis::getBackUpPlans($acronisData);
        if ( $planData->{status} == 200 ) {
            $planOptions = $planData->{data};
        }
    }
    Cpanel::Template::process_template(
        'whostmgr',
        {
            'template_file' => 'acronisbackup.tmpl',
            'data'          => {
                'version' => "Acronis Backup Manager .01",
            },
            'form'        => $prm,
            'options'     => $conf,
            'planoptions' => $planOptions,
        },
    );

    exit;
}

1;
