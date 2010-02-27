package Astro::UTDF;

use strict;
use warnings;

use Carp;
use IO::File ();
use Scalar::Util qw{ openhandle };
use Time::Local;

use constant PI => atan2( 0, -1 );
use constant TWO_PI => 2 * PI;
use constant SPEED_OF_LIGHT => 299792.458;	# Km/sec, per NIST

our $VERSION = '0.000_01';

sub azimuth {
    my ( $self ) = @_;
    exists $self->{_azimuth} and return $self->{azimuth};
    return ( $self->{_azimuth} = $self->{azimuth} * TWO_PI );
}

{

    my %decoder = (
	data_validity => '0x%02x',
	frequency_band => [
	    'unspecified',
	    'VHF',
	    'UHF',
	    'S-band',
	    'C-band',
	    'X-band',
	    'Ku-band',
	    'visible',
	    'S-band uplink/Ku-band downlink',
	    'unknown code 9',
	    'unknown code 10',
	    'unknown code 11',
	    'unknown code 12',
	    'unknown code 13',
	    'unknown code 14',
	    'unknown code 15',
	],
	measurement_time => sub {
	    return scalar gmtime $_[0]->measurement_time();
	},
	mode => '0x%04x',
	raw_record => sub {
	    return unpack 'H*', $_[0]->raw_record();
	},
	tracking_mode => [
	    'autotrack',
	    'program track',
	    'manual',
	    'slaved',
	],
	transmission_type => [
	    'test',
	    'unused',
	    'simulated',
	    'resubmit',
	    'RT (real time)',
	    'PB (playback)',
	    'unused',
	    'unused',
	    'unused',
	    'unused',
	    'unused',
	    'unused',
	    'unused',
	    'unused',
	    'unused',
	    'unused',
	],
    );

    sub decode {
	my ( $self, $method, @args ) = @_;
	my $dcdr = $decoder{$method}
	    or return $self->$method( @args );
	my $type = ref $dcdr
	    or return sprintf $dcdr, $self->$method( @args );
	'ARRAY' eq $type
	    and return $dcdr->[ $self->$method( @args ) ];
	'CODE' eq $type
	    and return $dcdr->( $self, @args );
	confess "Programming error -- decoder for $method is $type";
    }
}

sub doppler_count {
    my ( $self ) = @_;
    exists $self->{_doppler_count} and return $self->{_doppler_count};
    return ( $self->{_doppler_count} =
	    $self->{doppler_count_hi} * 65536 + $self->{doppler_count_lo}
    );
}

sub elevation {
    my ( $self ) = @_;
    exists $self->{_elevation} and return $self->{_elevation};
    my $elev = $self->{elevation} * TWO_PI;
    $elev >= PI and $elev -= TWO_PI;
    return ( $self->{_elevation} = $elev );
}

sub is_angle_valid {
    my ( $self ) = @_;
    return ( $self->{data_validity} & 0x4 ) ? 1 : 0;
}

sub is_doppler_valid {
    my ( $self ) = @_;
    return ( $self->{data_validity} & 0x2 ) ? 1 : 0;
}

sub is_range_valid {
    my ( $self ) = @_;
    return ( $self->{data_validity} & 0x1 ) ? 1 : 0;
}

sub range_rate {
    my ( $self ) = @_;
    exists $self->{_range_rate} and return $self->{_range_rate};
    if ( defined ( my $shift = $self->doppler_shift() ) ) {
	return ( $self->{_range_rate} =
	    - SPEED_OF_LIGHT / ( 2 * $self->transmit_frequency() *
		$self->_factor_K() ) * $shift
	);
    } else {
	return ( $self->{_range_rate} = undef );
    }
}

sub range_delay {
    my ( $self ) = @_;
    exists $self->{_range_delay} and return $self->{_range_delay};
    return ( $self->{_range_delay} =
	    ( $self->{range_delay_hi} * 65536 + $self->{range_delay_lo}
		) / 256
    );
}

use constant UTDF_TEMPLATE => 'a3A2CnnNNNNNnNnnNCCCCnCCna18a3';

sub slurp {
    my ( $class, $fh ) = @_;
    my $fn;
    if ( ! openhandle( $fh ) ) {
	$fn = $fh;
	-f $fn or croak "$fn not a normal file";
	$fh = IO::File->new( $fn, '<' )
	    or croak "Unable to open $fn: $!";
    }
    binmode $fh;
    my @rslt;
    my ( $buffer, $count );
    while ( $count = read $fh, $buffer, 75 ) {
	my %utdf;
	@utdf{ qw{ front router year sic vid seconds_of_year
	    microseconds_of_year azimuth elevation
	    range_delay_hi range_delay_lo
	    doppler_count_hi doppler_count_lo
	    agc
	    transmit_frequency
	    transmit_antenna_type
	    transmit_antenna_padid
	    receive_antenna_type
	    receive_antenna_padid
	    mode
	    data_validity
	    frequency_band_and_transmission_type
	    tracker_type_and_data_rate
	    tdrss_only
	    rear
	    } } = unpack UTDF_TEMPLATE, $buffer;
	$utdf{raw_record} = $buffer;
	my $obj = bless \%utdf, $class;
	if ( @rslt ) {
	    my $count = $obj->doppler_count() - $rslt[-1]->doppler_count();
	    $count < 0 and $count += 2 << 48;
	    my $deltat = $obj->measurement_time() -
		$rslt[-1]->measurement_time();
	    $utdf{doppler_shift} = ( $count / $deltat - 240_000_000 ) /
		$obj->_factor_M();
	}

	push @rslt, $obj;
    }
    close $fh;
    return @rslt;
}

sub tracker_type {
    my ( $self ) = @_;
    exists $self->{_tracker_type} and return $self->{_tracker_type};
    return ( $self->{_tracker_type} =
	( $self->{tracker_type_and_data_rate} & 0xF000 ) >> 12 );
}

sub tracking_mode {
    my ( $self ) = @_;
    exists $self->{_tracking_mode} and return $self->{_tracking_mode};
    return ( $self->{_tracking_mode} = ( $self->{mode} & 0x000C ) >> 2 );
}

sub transmission_type {
    my ( $self ) = @_;
    exists $self->{_transmission_type} and return $self->{_transmission_type};
    return ( $self->{_transmission_type} =
	$self->{frequency_band_and_transmission_type} & 0x0F );
}

sub transmit_frequency {
    my ( $self ) = @_;
    exists $self->{_transmit_frequency}
	and return $self->{_transmit_frequency};
    return ( $self->{_transmit_frequency} =
	$self->{transmit_frequency} * 10 );
}

# Generate all the canonical accessors. If there exists a method named
# after the attribute (with an underscore prepended) we generate an
# accessor that calls the method and caches the result, returning the
# cached value for subsequent calls. If not, we just return the named
# attribute, which is assumed to already exist.

foreach my $accessor ( qw{
    front router year sic vid seconds_of_year
    microseconds_of_year
    agc
    transmit_antenna_type
    transmit_antenna_padid
    receive_antenna_type
    receive_antenna_padid
    mode
    data_validity
    frequency_band_and_transmission_type
    tracker_type_and_data_rate
    tdrss_only
    rear
    raw_record
    doppler_shift

    frequency_band
    measurement_time
} ) {
    my $compute = "_$accessor";
    no strict qw{ refs };
    *$accessor = __PACKAGE__->can( $compute ) ?
    sub {
	my ( $self, @args ) = @_;
	exists $self->{_cache}{$accessor}
	    and return $self->{_cache}{$accessor};
	return ( $self->{_cache}{$accessor} = $self->$compute( @args ) );
    } :
    sub {
	return $_[0]->{$accessor};
    };
}

# Return the factor M, which is documented as 1000 for S-band or 100 for
# K-band. Since we know we can't count on the frequency_band, we
# compute this ourselves, making the break at the bottom of the Ku band.

sub _factor_M {
    my ( $self ) = @_;
    return $self->transmit_frequency() >= 12_000_000_000 ? 100 : 1000;
}

# Return the factor K, which is documented as 240/221 for S-band or 1
# for VHF. Since we know we can't count on the frequency_band, we
# compute this ourselves, making the break at the bottom of the S band.

sub _factor_K {
    my ( $self ) = @_;
    return $self->transmit_frequency() >= 2_000_000_000 ? 240 / 221 : 1;
}

# Return the frequency band code, which is the high nybble of the
# frequency_band_and_transmission_type field.

sub _frequency_band {
    my ( $self ) = @_;
    return ( $self->{frequency_band_and_transmission_type} & 0xF0 ) >> 4;
}

# Return the measurement time as a Perl time in seconds since the Perl
# epoch.

sub _measurement_time {
    my ( $self ) = @_;
    my $yr = $self->year();
    $yr < 70 and $yr += 100;
    return timegm( 0, 0, 0, 1, 0, $yr ) + $self->seconds_of_year() +
	$self->microseconds_of_year() / 1_000_000;
}

1;

=head1 NAME

Astro::UTDF - Represent Universal Tracking Data Format (UTDF) data

=head1 SYNOPSIS

 use Astro::UTDF;
 my @data = Astro::UTDF->slurp( $file_name );
 foreach my $utdf ( @data ) {
     print join( "\t", scalar gmtime $utdf->time(),
         $utdf->azimuth(), $utdf->elevation(),
     ), "\n";
 }

=head1 DETAILS

This class represents a record from a Universal Tracking Data Format
(UTDF) file. The UTDF file can be read using the
L<< Astro::UTDF->slurp()|/slurp >> method, which is the only supported
way to instantiate this class.

=head1 METHODS

This class supports the following public methods:

=head2 agc

 print 'AGC is ', $utdf->agc(), "\n";

This method returns the value of the AGC signal level at the receiver.

This information comes from bytes 39-40 of the record.

=head2 azimuth

 print 'Azimuth is ', $utdf->azimuth(), " radians\n";

This method returns the value of the antenna azimuth in radians.
B<Note> that this is returned even if L</is_angle_valid> (bit 2 (from 0)
of the L</data_validity> attribute) is false.

This information comes from bytes 19-22 of the record.

=head2 data_validity

 printf "Data validity is 0x%02x\n", $utdf->data_validity();

This method returns the data validity mask. The bits (from bit 0 = least
significant) are:

 0 - range valid
 1 - range rate valid
 2 - angle valid
 3 - angle delta correction ( 1 = corrected )
 4 - refraction correction to angles ( 1 = corrected )
 5 - refraction correction to range, rate ( 1 = corrected )
 6 - destruct range rate ( 1 = destruct )
 7 - side lobe ( 1 = side lobe )

This information comes from byte 51 of the record.

=head2 decode

 print 'Measurement time: ',
 $utdf->decode( 'measurement_time' );

This method is a general-purpose accessor, producing human-readable
output when it knows how.  It takes as its arguments the name of a
method, and its arguments if any. If this method knows how to produce
human-readable output from the given method, it does so and returns the
human-readable output. Otherwise it simply calls the method and returns
its output.

This method knows how to produce human-readable output from the
following methods. Generally, the output comes pretty much verbatim from
the description of the given method's output.

 data_validity (in hexadecimal)
 measurement_time ( = scalar gmtime )
 mode (in hexadecimal)
 tracking_mode
 frequency_band_and_transmission_type

=head2 doppler_count

 print 'Doppler count is ', $utdf->doppler_count(), "\n";

This method returns the accumulated doppler count for the observation.
B<Note> that this is returned even if L</is_doppler_valid> (bit 1 (from
0) of the L</data_validity> attribute) is false.

This information comes from bytes 33-38 of the record.

=head2 doppler_shift

 print 'Doppler shift is ', $utdf->doppler_shift(), " Hertz\n";

This method returns the doppler shift of the data, in Hertz.

This information is calculated from the biased doppler frequency, which
in turn comes from the difference between the doppler counts of this
record and the previous record (accounting for count wrap if needed),
divided by the difference between the observation times of this record
and the previous record. Accordingly, this information is not available
for the first record in the file.

B<Note> that this is returned even if L</is_doppler_valid> (bit 1 (from
0) of the L</data_validity> attribute) of the two records involved is
false.

=head2 elevation

 print 'Elevation is ', $utdf->elevation(), " radians\n";

This method returns the elevation angle of the antenna, in radians.
B<Note> that this is returned even if L</is_angle_valid> (bit 2 (from 0)
of the L</data_validity> attribute) is false.

This information comes from bytes 19-22 of the record.

=head2 frequency_band

 printf "Frequency band is 0x%01x\n",
     $utdf->frequency_band();

This method returns a number from 0-15, extracted from the high nybble
of the L</frequency_band_and_transmission_type>, and encoded the same
way. This datum encodes the frequency band being used.

=head2 frequency_band_and_transmission_type

 printf "The frequency band and transmission type are 0x%02x\n",
     $utdf->frequency_band_and_transmission_type();

This method returns the frequency band and transmission type. The most
significant nybble encodes the frequency (in hexadecimal) as follows:

  0 - unspecified
  1 - VHF
  2 - UHF
  3 - S-band
  4 - C-band
  5 - X-band
  6 - Ku-band
  7 - visible
  8 - S-band uplink/Ku-band downlink
  9-F - unused

The least significant nybble encodes the transmission type (in
hexadecimal) as follows:

  0 - test
  1 - unused
  2 - simulated
  3 - resubmit
  4 - real time (normal setting)
  5 - playback

This information comes from byte 52 of the record.

=head2 front

 printf "The front 3 bytes are 0x%06x\n", $utdf->front();

This method returns the constant field at the front of the record, which
should always be 0x0d0a01.

This information comes from bytes 1-3 of the record.

=head2 is_angle_valid

 print 'Angle data are ', (
     $utdf->is_angle_valid() ? '' : 'not' ), " valid\n";

This method returns true if the angle data are valid, and false if not.
The angle data are considered valid if bit 2 (from 0) of
L<< $utdf->data_validity()|/data_validity >> is set.

=head2 is_doppler_valid

 print 'Doppler data are ', (
     $utdf->is_doppler_valid() ? '' : 'not' ), " valid\n";

This method returns true if the doppler data are valid, and false if
not.  The doppler data are considered valid if bit 1 (from 0) of
L<< $utdf->data_validity()|/data_validity >> is set.

=head2 is_range_valid

 print 'Range data are ', (
     $utdf->is_range_valid() ? '' : 'not' ), " valid\n";

This method returns true if the range data are valid, and false if not.
The range data are considered valid if bit 0 (from 0) of
L<< $utdf->data_validity()|/data_validity >> is set.

=head2 measurement_time

 print 'Measured at ',
     scalar gmtime $utdf->measurement_time(),
     " GMT\n";

This method returns the time the measurement was taken as a Perl time.

This information is constructed from the year field, the seconds_of_year
field, and the microseconds_of_year field.

=head2 microseconds_of_year

 print 'Measured at ',
     $utdf->microseconds_of_year(),
     " microseconds after the second.\n";

This method returns the number of microseconds after the second the
measurement was taken.

This information comes from bytes 15-18 of the record.

=head2 mode

 printf "System-unique mode: 0x%04x\n", $utdf->mode();

This method returns the system-unique mode information. The data depend
on the system being used, and are encoded in the bits of the mode as
follows, 0 being the least-significant bit:

=over

=item C-band

 0     0 = beacon, 1 = skin
 1     0
 2-3   00 = autotrack
       01 = program track
       02 = manual
       03 = slaved
 4-15  unused

=item SRE

 0     0 = coherent, 1 = incoherent
 1     0 = secondary, 1 = primary
 2-3   see C-band
 4-5   00 = unused
       01 = 1-way
       10 = 2-way
       11 = 3-way
 6-7   -1 = lowest sidetone 10 Hz
 8-9   00 = not used
       01 = major tone 20 KHz
       10 = major tone 100 KHz
       11 = major tone 500 KHz
 10-12 Autotrack MFR, 1-6 (0 = unknown)
 13-15 Range MFR, 1-4 (0 = unknown)

=item SRE-VHF

 0-1   unused
 2-3   see C-band
 4-5   unused
 6-9   see SRE

=back

This information comes from bytes 49-50 of the record.

=head2 range_delay

 print 'Range delay ', $utdf->range_delay(), " nanoseconds\n";

This method returns the range delay (tracker to spacecraft to tracker)
in nanoseconds.  B<Note> that this is returned even if
L</is_range_valid> (bit 0 (from 0) of the L</data_validity> attribute)
is false.  According to the specification this includes transponder
latency in the satellite, but not latency at the ground station.

This information comes from bytes 27-32 of the record.

=head2 range_rate

 print 'Range rate ', $utdf->range_rate(), " km/second\n";

This method returns the range rate, or velocity in recession.

This is calculated from the Doppler shift.

=head2 raw_record

 print 'Raw record in hex: ', unpack( 'H*', $utdf->raw_record() ), "\n";

This method returns the raw record as read from the file.

=head2 rear

 printf "The rear 3 bytes are 0x%06x\n", $utdf->rear();

This method returns the constant field at the end of the record, which
should always be 0x040f0f.

This information comes from bytes 73-75 of the record.

=head2 receive_antenna_padid

 print 'The receive antenna PADID is ',
     $utdf->receive_antenna_padid(), "\n";

This method returns the receive antenna PADID.

This information comes from byte 48 of the record.

=head2 receive_antenna_type

 print 'The receive antenna diameter/type code is ',
     $utdf->receive_antenna_type(), "\n";

This method returns the receive antenna diameter/type code. This is a
byte, encoded the same way as the L</transmit_antenna_type>.

This information comes from byte 47 of the record.

=head2 router

 print 'Tracking data router: ', $utdf->router(), "\n";

This method returns the tracking data router, encoded as two ASCII
characters. Known codes are:

 AA = GSFC
 DD = GSFC
 FF = GSFC/France (CNES)
 HH = GSFC/Japan
 II = GSFC/Germany (ESRO)
 JJ = GSFC/JSC

This information comes from bytes 4-5 of the record.

=head2 seconds_of_year

 print 'Measured at ', $utdf->seconds_of_year(),
     " seconds after the start of the year\n";

This method returns the number of seconds after the start of the year
the measurement was taken.

This information comes from bytes 11-14 of the record.

=head2 sic

 print 'The SIC is ', $utdf->sic(), "\n";

This method returns the SIC. I have no further information on what this
is.

This information comes from bytes 7-8 of the record.

=head2 slurp

 my @data = Astro::UTDF->slurp( $file_name );

This static method reads the given file, returning an array of
Astro::UTDF objects.

=head2 tdrss_only

This method returns the 18 bytes of the record that are for Space
Network (TDRSS) use only.

This information comes from bytes 55-72 of the record.

=head2 tracker_type

 printf "Tracker type: 0x%01x\n", $utdf->tracker_type();

This method returns the tracker type. This is extracted from the high
nybble of L</tracker_type_and_data_rate>, and is encoded the same way.

=head2 tracker_type_and_data_rate

 printf "Tracker type and data rate: 0x%04x\n",
     $utdf->tracker_type_and_data_rate();

This method returns the tracker type and data rate. The most significant
nybble encodes the tracker type as follows (in hexadecimal):

  0 - C-band pulse track
  1 - SRE (S-band and VHF) or RER
  2 - X-Y angles only
  3 - unused
  4 - SGLS (AFSCF S-band trackers)
  5 - unused
  6 - TDRSS
  7 - STGT/WSGTU
  8 - TDRSS TT&C
  9-F - unused

The high bit of the next-most-significant nybble is 1 for the last data
frame.

The rest of this 2-byte field (i.e. the low 11 bits) encode data rate.
If the high bit is off, it is the interval between samples in seconds.
If the high bit is on, it is the twos complement of number of samples
per second.

This information comes from bytes 53-54 of the record.

=head2 tracking_mode

 print 'The tracking mode is ', $utdf->tracking_mode(), "\n";

This method returns the tracking mode. The data come from bits 2-3 of
the L</mode> field, and the encoding is documented there.

=head2 transmission_type

 print 'The transmission type is ', $utdf->transmission_type(), "\n";

This method returns the transmission type. This information comes from
the low nybble of the L</frequency_code_and_transmission_type>, and the
encoding is documented there.

=head2 transmit_antenna_padid

 print 'The transmit antenna PADID is ',
     $utdf->transmit_antenna_padid(), "\n";

This method returns the transmit antenna PADID.

This information comes from byte 46 of the record.

=head2 transmit_antenna_type

 print 'The transmit antenna diameter/type code is ',
     $utdf->transmit_antenna_type(), "\n";

This method returns the transmit antenna diameter/type code. This is a
byte, whose most-significant nybble encodes the antenna size as follows
(in hexadecimal):

 0 - less than 1 meter
 1 - 3.9 meter
 2 - 4.3 meter
 3 - 9 meter
 4 - 12 meter
 5 - 26 meter
 6 - TDRSS ground antenna
 7 - 6 meter
 8 - 7.3 meter
 9 - 8 meter
 A-F - unused

Antennae not on the list are encoded to the nearest size that is on the
list. The least-significant nybble encodes the antenna geometry as
follows (in hexadecimal):

 0 - az-el
 1 - X-Y (+X south)
 2 - X-Y (+X east)
 3 - RA-DEC
 4 - HR-DEC
 5-F - unused

This information comes from byte 45 of the record.

=head2 transmit_frequency

 print 'The transmit frequency is ',
     $utdf->transmit_frequency(), " Hertz\n";

This method returns the transmit frequency in Hertz.

This information comes from bytes 41-44 of the record.

=head2 vid

 print 'The VID is ', $utdf->vid(), "\n";

This method returns the Vehicle ID for the record.

This information comes from bytes 9-10 of the record.

=head2 year

 printf "The year is %02d\n", $utdf->year();

This method returns the year the measurement was taken, modulo 100 (i.e.
the last two digits.

This information comes from byte 6 of the record.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009, Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

__END__

# ex: set textwidth=72 :
