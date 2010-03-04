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
returns( $utdf, data_interval => 256, 'data_interval' );
returns( $utdf, data_validity => 2, 'data_validity' );
decode ( $utdf, data_validity => '0x02', 'decode data_validity' );
decode ( $utdf, frequency_band => 'unspecified', 'decode frequency_band' );
decode ( $utdf, measurement_time => 'Tue Dec  8 01:41:51 2009',
    'decode measurement_time' );
decode ( $utdf, mode => '0x0220', 'decode mode' );
decode ( $utdf, raw_record =>
    '0d0a014141090cb2000101c1a75f000000000000000000000000000000000000000a2ccf263c00000c364d9840574057022002000100000000000000000000000000000000000000040f0f',
    'decode raw_record' );
decode ( $utdf, tracking_mode => 'autotrack', 'decode tracking_mode' );
decode ( $utdf, transmission_type => 'test', 'decode transmission_type' );
returns( $utdf, doppler_count => 43701446204, 'doppler_count' );
returns( $utdf, doppler_shift => 40131.725, 'doppler_shift' );
returns( $utdf, elevation => 0, 'elevation' );
returns( $utdf, frequency_band => 0, 'frequency_band' );
returns( $utdf, frequency_band_and_transmission_type => 0,
    'frequency_band_and_transmission_type' );
hexify ( $utdf, front => '0d0a01', 'front' );
returns( $utdf, hex_record =>
    '0d0a014141090cb2000101c1a75f000000000000000000000000000000000000000a2ccf263c00000c364d9840574057022002000100000000000000000000000000000000000000040f0f',
    'hex_record' );
returns( $utdf, is_angle_valid => 0, 'is_angle_valid' );
returns( $utdf, is_doppler_valid => 1, 'is_doppler_valid' );
returns( $utdf, is_range_valid => 0, 'is_range_valid' );
returns( $utdf, is_last_frame => 0, 'is_last_frame' );
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

SKIP: {

    local $@;
    my $clone;

    ok( eval { $clone = $utdf->clone() }, 'Clone our object' )
	or skip( "Failed to clone object", 6 );

    ok( eval { $clone->enforce_validity( 1 ) }, 'Set enforce_validity' )
	or skip( "Failed to set enforce_validity", 5 );

    ok( eval { $clone->enforce_validity() },
	'See if enforce_validity is set' )
	or skip( "Failed to set enforce_validity", 4 );

    returns( $clone, azimuth => undef, 'azimuth (invalid)' );
    returns( $clone, doppler_count => 43701446204, 'doppler_count (valid)' );
    returns( $clone, elevation => undef, 'elevation (invalid)' );
    returns( $clone, range_delay => undef, 'range_delay (invalid)' );

}

{
    my ( undef, $obj ) = Astro::UTDF->slurp( file => 't/doppler.utdf',
	enforce_validity => 1 );
    ok( eval { $obj->enforce_validity() },
	'Can pass attributes to slurp()' );
}

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
