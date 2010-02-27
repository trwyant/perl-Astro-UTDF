package main;

use strict;
use warnings;

BEGIN {
    eval {
	require Test::More;
	Test::More->VERSION( 0.40 );
	Test::More->import();
	1;
    } or do {
	print "1..0 # skip Test::More 0.40 required\n";
	exit;
    }
}

use Astro::UTDF;

plan( 'no_plan' );

my ( $prior, $utdf ) = Astro::UTDF->slurp( 't/doppler.utdf' );

returns( $utdf, agc => 0, 'agc' );
returns( $utdf, azimuth => 0, 'azimuth' );
returns( $utdf, data_validity => 2, 'data_validity' );
decode ( $utdf, data_validity => '0x02', 'decode data_validity' );
decode ( $utdf, frequency_band => 'unspecified', 'decode frequency_band' );
decode ( $utdf, measurement_time => 'Tue Dec  8 01:41:51 2009',
    'decode measurement_time' );
decode ( $utdf, mode => '0x0220', 'decode mode' );
decode ( $utdf, tracking_mode => 'autotrack', 'decode tracking_mode' );
decode ( $utdf, transmission_type => 'test', 'decode transmission_type' );
returns( $utdf, doppler_count => 43701446204, 'doppler_count' );
returns( $utdf, doppler_shift => 40131.725, 'doppler_shift' );
returns( $utdf, elevation => 0, 'elevation' );
returns( $utdf, frequency_band => 0, 'frequency_band' );
returns( $utdf, frequency_band_and_transmission_type => 0,
    'frequency_band_and_transmission_type' );
hexify ( $utdf, front => '0d0a01', 'front' );
returns( $utdf, is_angle_valid => 0, 'is_angle_valid' );
returns( $utdf, is_doppler_valid => 1, 'is_doppler_valid' );
returns( $utdf, is_range_valid => 0, 'is_range_valid' );
returns( $utdf, measurement_time => 1260236511, 'measurement_time' );
returns( $utdf, microseconds_of_year => 0, 'microseconds_of_year' );
returns( $utdf, mode => 544, 'mode' );
returns( $utdf, range_rate => -2.70363808094889, 'range_rate' );
returns( $utdf, range_delay => 0, 'range_delay' );
hexify ( $utdf, rear => '040f0f', 'rear' );
returns( $utdf, receive_antenna_padid => 87, 'receive_antenna_padid' );
returns( $utdf, receive_antenna_type => 64, 'receive_antenna_type' );
returns( $utdf, router => 'AA', 'router' );
returns( $utdf, seconds_of_year => 29468511, 'seconds_of_year' );
returns( $utdf, sic => 3250, 'sic' );
hexify ( $utdf, tdrss_only => '000000000000000000000000000000000000',
    'tdrss_only' );
returns( $utdf, tracker_type => 0, 'tracker_type' );
returns( $utdf, tracker_type_and_data_rate => 256,
    'tracker_type_and_data_rate' );
returns( $utdf, tracking_mode => 0, 'tracking_mode' );
returns( $utdf, transmission_type => 0, 'transmission_type' );
returns( $utdf, transmit_antenna_padid => 87, 'transmit_antenna_padid' );
returns( $utdf, transmit_antenna_type => 64, 'transmit_antenna_type' );
returns( $utdf, transmit_frequency => 2048854000, 'transmit_frequency' );
returns( $utdf, vid => 1, 'vid (Vehicle ID)' );
returns( $utdf, year => 9, 'year' );

sub decode {
    splice @_, 1, 0, 'decode';
    goto &returns;
}

sub hexify {
    splice @_, 1, 0, { unpack => 'H*' };
    goto &returns;
}

sub returns {
    my ( $obj, @args ) = @_;
    my $opt = ref $args[0] eq 'HASH' ? shift @args : {};
    my $method = shift @args;
    my $name = pop @args;
    my $want = pop @args;
    my $got;
    eval { $got = $obj->$method( @args ); 1 }
	or do {
	@_ = "$name threw $@";
	goto &fail;
    };
    if ( $opt->{unpack} ) {
	$got = unpack $opt->{unpack}, $got;
    }
    @_ = ( $got, $want, $name );
    goto &is;
}

1;

# ex: set textwidth=72 :
