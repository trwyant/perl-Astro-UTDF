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

    $obj->enforce_validity( 0 );

    $obj->agc( 10000 );
    returns( $obj, agc => 10000, 'Round-trip agc' );

    $obj->azimuth( 1 );
    returns( $obj, { sprintf => '%.8f' }, azimuth => '1.00000000',
	'Round-trip azimuth' );

    $obj->data_interval( 1 );
    returns( $obj, data_interval => 1, 'Round-trip data_interval' );

    $obj->data_validity( 7 );
    returns( $obj, data_validity => 7, 'Round-trip data_validity' );

    $obj->doppler_count( 123456789 );
    returns( $obj, doppler_count => 123456789, 'Round-trip doppler_count' );

    $obj->elevation( 1 );
    returns( $obj, { sprintf => '%.8f' }, elevation => '1.00000000',
	'Round-trip elevation' );

    $obj->frequency_band( 3 );
    returns( $obj, frequency_band => 3, 'Round-trip frequency_band' );

    $obj->frequency_band_and_transmission_type( 1028 );
    returns( $obj, frequency_band_and_transmission_type => 1028,
	'Round-trip frequency_band_and_transmission_type' );

    $obj->is_angle_valid( 'true' );
    returns( $obj, is_angle_valid => 1, 'Round-trip is_angle_valid' );

    $obj->is_doppler_valid( undef );
    returns( $obj, is_doppler_valid => 0, 'Round-trip is_doppler_valid' );

    $obj->is_range_valid( [] );
    returns( $obj, is_range_valid => 1, 'Round-trip is_range_valid' );

    $obj->is_last_frame( 1 );
    returns( $obj, is_last_frame => 1, 'Round-trip is_last_frame' );

    # TODO measurement_time

    $obj->microseconds_of_year( 314159 );
    returns( $obj, microseconds_of_year => 314159,
	'Round-trip microseconds_of_year' );

    $obj->mode( 12 );
    returns( $obj, mode => 12, 'Round-trip mode' );

    $obj->range_delay( 9876543210 );
    returns( $obj, range_delay => 9876543210, 'Round-trip range_delay' );

    $obj->receive_antenna_padid( 42 );
    returns( $obj, receive_antenna_padid => 42,
	'Round-trip receive_antenna_padid' );

    $obj->receive_antenna_type( 1025 );
    returns( $obj, receive_antenna_type => 1025,
	'Round-trip receive_antenna_type' );

    $obj->router( '??' );
    returns( $obj, router => '??', 'Round-trip router' );

    $obj->seconds_of_year( 9999999 );
    returns( $obj, seconds_of_year => 9999999,
	'Round-trip seconds_of_year' );

    $obj->sic( 86 );
    returns( $obj, sic => 86, 'Round-trip sic' );

    $obj->tdrss_only( 'Hello, world!' );
    returns( $obj, tdrss_only => 'Hello, world!',
	'Round-trip tdrss_only' );

    $obj->tracker_type( 9 );
    returns( $obj, tracker_type => 9, 'Round-trip tracker_type' );

    $obj->tracker_type_and_data_rate( 2 );
    returns( $obj, tracker_type_and_data_rate => 2,
	'Round-trip tracker_type_and_data_rate' );

    # TODO tracking_mode

    $obj->transmission_type( 10 );
    returns( $obj, transmission_type => 10,
	'Round-trip transmission_type' );

    $obj->transmit_antenna_padid( 42 );
    returns( $obj, transmit_antenna_padid => 42,
	'Round-trip transmit_antenna_padid' );

    $obj->transmit_antenna_type( 1025 );
    returns( $obj, transmit_antenna_type => 1025,
	'Round-trip transmit_antenna_type' );

    # TODO transmit_frequency

    $obj->vid( 99 );
    returns( $obj, vid => 99, 'Roumnd-trip vid' );

    $obj->year( 8 );
    returns( $obj, year => 8, 'Round-trip year' );

    # TODO all the simple accessors
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
    $opt->{unpack}
	and $got = unpack $opt->{unpack}, $got;
    $opt->{sprintf}
	and $got = sprintf $opt->{sprintf}, $got;
    @_ = ( $got, $want, $name );
    goto &is;
}

1;

# ex: set textwidth=72 :
