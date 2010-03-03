package Astro::UTDF;

use strict;
use warnings;

use Carp;
use IO::File ();
use Params::Util 0.25 qw{ _INSTANCE };
use Scalar::Util qw{ openhandle };
use Time::Local;

use constant FULL_CIRCLE => 4294967296;	# 2 ** 32;
use constant PI => atan2( 0, -1 );
use constant TWO_PI => 2 * PI;
use constant SPEED_OF_LIGHT => 299792.458;	# Km/sec, per U.S. NIST

our $VERSION = '0.000_02';

# Perl::Critic annotation required because of the assignment to @_
# before the co-routine call to clone().
sub new {	## no critic (RequireArgUnpacking)
    my ( $class, @args ) = @_;
    ref $class and $class = ref $class;
    @_ = ( $class, @args );
    goto &clone;
}

sub azimuth {
    my ( $self, @args ) = @_;
    @args and croak "azimuth() may not be used as a mutator";
    $self->enforce_validity()
	and not $self->is_angle_valid()
	and return undef;	## no critic (ProhibitExplicitReturnUndef)
    return $self->{azimuth} / FULL_CIRCLE * TWO_PI;
}

sub clone {
    my ( $self, @args ) = @_;
    my ( $class, $clone );
    if ( $class = ref $self ) {
	$clone = {};
	while ( my ( $name, $value ) = each %{ $self } ) {
	    $clone->{$name} = $value;
	}
    } else {
	$clone = { _static() };
	$class = $self;
    }
    bless $clone, $class;
    while ( @args ) {
	my ( $name, $value ) = splice @args, 0, 2;
	my $code = $clone->can( $name )
	    or croak "Method $name() not found";
	$code->( $clone, $value );
    }
    return $clone;
}

# TODO sub data_rate
# This is the low 3 nybbles of transmission_type_and_data_rate, encoded
# per that field's docs. I want to get it to consistent units, which I
# think will be seconds.

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
    my ( $self, @args ) = @_;
    @args and croak "doppler_count() may not be used as a mutator";
    $self->enforce_validity()
	and not $self->is_doppler_valid()
	and return undef;	## no critic (ProhibitExplicitReturnUndef)
    return $self->{doppler_count_hi} * 65536 + $self->{doppler_count_lo};
}

sub doppler_shift {
    my ( $self, @args ) = @_;
    @args and croak "doppler_shift() may not be used as a mutator";
    # Note that this can never be a mutator, because it uses data from
    # more than one record.
    defined( my $prior = $self->prior_record() )
	# If I simply returned as PBP would have me do, this method
	# would behave differently in list context depending on whether
	# prior_record() returned a defined value.
	or return undef;	## no critic (ProhibitExplicitReturnUndef)
    $self->enforce_validity()
	and not ( $self->is_doppler_valid() &&
	    $prior->is_doppler_valid() )
	and return undef;	## no critic (ProhibitExplicitReturnUndef)
    my $count = $self->doppler_count() - $prior->doppler_count();
    my $deltat = $self->measurement_time() - $prior->measurement_time();
    if ( $deltat < 0 ) {
	$deltat = - $deltat;
	$count = - $count;
    }
    $count < 0 and $count += 2 << 48;
    return ( $count / $deltat - 240_000_000 ) / $self->_factor_M();
}

sub elevation {
    my ( $self, @args ) = @_;
    @args and croak "elevation() may not be used as a mutator";
    $self->enforce_validity()
	and not $self->is_angle_valid()
	and return undef;	## no critic (ProhibitExplicitReturnUndef)
    my $elev = $self->{elevation} / FULL_CIRCLE * TWO_PI;
    $elev >= PI and $elev -= TWO_PI;
    return $elev;
}

sub enforce_validity {
    my ( $self, @args ) = @_;
    if ( @args ) {
	$self->{enforce_validity} = shift @args;
	return $self;
    } else {
	return $self->{enforce_validity};
    }
}

sub frequency_band {
    splice @_, 1, 0, frequency_band_and_transmission_type => 1;
    goto &_bash_nybble;
}

sub hex_record {
    my ( $self, @args ) = @_;
    if ( @args ) {
	return $self->raw_record( pack 'H*', $args[0] );
    } else {
	return unpack 'H*', $self->raw_record();
    }
}

sub is_angle_valid {	## no critic (RequireArgUnpacking)
    splice @_, 1, 0, data_validity => 2;
    goto &_bash_bit;
}

sub is_doppler_valid {	## no critic (RequireArgUnpacking)
    splice @_, 1, 0, data_validity => 1;
    goto &_bash_bit;
}

sub is_range_valid {	## no critic (RequireArgUnpacking)
    splice @_, 1, 0, data_validity => 0;
    goto &_bash_bit;
}

sub is_last_frame {	## no critic (RequireArgUnpacking)
    splice @_, 1, 0, tracker_type_and_data_rate => 11;
    goto &_bash_bit;
}

sub measurement_time {
    my ( $self, @args ) = @_;
    @args and croak "measurement_time() may not be used as a mutator";
    my $yr = $self->year();
    $yr < 70 and $yr += 100;
    return timegm( 0, 0, 0, 1, 0, $yr ) + $self->seconds_of_year() +
	$self->microseconds_of_year() / 1_000_000;
}

sub prior_record {
    my ( $self, @args ) = @_;
    if ( @args ) {
	my $prior = shift @args;
	defined $prior and not _INSTANCE( $prior, __PACKAGE__ )
	    and croak 'Prior record must be undef or a ', __PACKAGE__;
	$self->{prior_record} = $prior;
	return $self;
    } else {
	return $self->{prior_record};
    }
}

sub range_delay {
    my ( $self, @args ) = @_;
    @args and croak "range_delay() may not be used as a mutator";
    $self->enforce_validity()
	and not $self->is_range_valid()
	and return undef;	## no critic (ProhibitExplicitReturnUndef)
    return ( $self->{range_delay_hi} * 65536 +
	$self->{range_delay_lo} ) / 256;
}

sub range_rate {
    my ( $self, @args ) = @_;
    @args and croak "range_rate() may not be used as a mutator";
    # Note that this can never be a mutator because it uses
    # doppler_shift() (q.v.)
    if ( defined ( my $shift = $self->doppler_shift() ) ) {
	return (
	    - SPEED_OF_LIGHT / ( 2 * $self->transmit_frequency() *
		$self->_factor_K() ) * $shift
	);
    } else {
	# If I simply returned as PBP would have me do, this method
	# would behave differently in list context depending on whether
	# doppler_shift() returned a defined value.
	return undef;	## no critic (ProhibitExplicitReturnUndef)
    }
}

{

    my $utdf_template = 'a3A2CnnNNNNNnNnnNCCCCnCCna18a3';
    my @utdf_fields = qw{
	front router year sic vid seconds_of_year
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
    };

    sub raw_record {
	my ( $self, @args ) = @_;
	if ( @args ) {
	    my $raw_record = shift @args;
	    length $raw_record == 75
		or croak "Invalid raw record: length not 75 bytes";
	    @$self{ @utdf_fields } = unpack $utdf_template, $raw_record;
	    return $self;
	} else {
	    return pack $utdf_template, @$self{ @utdf_fields };
	}
    }

    my $static;
    @$static{ @utdf_fields } = ( 0 ) x scalar @utdf_fields;
    $static->{front} = pack 'H*', '0d0a01';
    $static->{router} = ' ';
    $static->{tdrss_only} = pack( 'H*', '00' ) x 18;
    $static->{rear} = pack 'H*', '040f0f';
    bless $static, __PACKAGE__;

    sub _static {
	return wantarray ? %{ $static } : $static;
    }
}

{

    my %my_arg = map { $_ => 1 } qw{ file };

    sub slurp {
	my ( $class, @in_args ) = @_;

	@in_args % 2 and unshift @in_args, 'file';
	my ( %arg, @attrib );
	while ( @in_args ) {
	    my ( $name, $value ) = splice @in_args, 0, 2;
	    if ( $my_arg{$name} ) {
		$arg{$name} = $value;
	    } else {
		push @attrib, $name, $value;
	    }
	}
	$arg{file} or croak "File not specified";

	my $fh = $arg{file};
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
	    push @rslt, __PACKAGE__->new(
		raw_record => $buffer,
		prior_record => ( @rslt ? $rslt[-1] : undef ),
		@attrib,
	    );
	}
	close $fh;
	return @rslt;
    }

}

sub tracker_type {
    splice @_, 1, 0, tracker_type_and_data_rate => 3;
    goto &_bash_nybble;
}

sub tracking_mode {
    my ( $self, @args ) = @_;
    @args and croak "tracking_mode() may not be used as a mutator";
    return ( $self->{mode} & 0x000C ) >> 2;
}

sub transmission_type {
    splice @_, 1, 0, frequency_band_and_transmission_type => 0;
    goto &_bash_nybble;
}

sub transmit_frequency {
    my ( $self, @args ) = @_;
    @args and croak "transmit_frequency() may not be used as a mutator";
    return $self->{transmit_frequency} * 10;
}

# Generate all the simple accessors. These just return the value of
# the correspondingly-named attribute, which is assumed to exist.

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
} ) {
    no strict qw{ refs };
    *$accessor = sub {
	my ( $self, @args ) = @_;
	@args and croak "$accessor() may not be used as a mutator";
	return $_[0]->{$accessor};
    };
}

# Generic accessor/mutator for single bits. The specific
# accessor/mutator splices the attribute name and the bit number into
# the argument list after the object, and co-routines to this (or calls
# it returning whatever it returns). NOTE: I would love to use vec()
# here, but that works on strings.
sub _bash_bit {
    my ( $self, $attr, $bit, @args ) = @_;
    my $mask = 0x01 << $bit;
    if ( @args ) {
	if ( $args[0] ) {
	    $self->{$attr} |= $mask;
	} else {
	    $self->{$attr} &= ~ $mask;
	}
	return $self;
    } else {
	return $self->{$attr} & $mask ? 1 : 0;
    }
}

# Generic accessor/mutator for nybbles. The specific accessor/mutator
# splices the attribute name and the nybble number into the argument
# list after the object, and co-routines to this (or calls it returning
# whatever it returns). NOTE: I would love to use vec() here, but that
# works on strings.
sub _bash_nybble {
    my ( $self, $attr, $bit, @args ) = @_;
    my $shift = 4 * $bit;
    my $mask = 0x0f << $shift;
    if ( @args ) {
	$self->{$attr} &= ~ $mask;
	$self->{$attr} |= ( $args[0] & 0x0f ) << $shift;
	return $self;
    } else {
	return ( $self->{$attr} & $mask ) >> $shift;
    }
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

1;

__END__

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
L<< Astro::UTDF->slurp()|/slurp >> method, which returns a list of
Astro::UTDF objects.

Most of the following methods are accessors of some sort. Some of the
accessors will also behave as mutators if you pass a new value as an
argument. Validation is minimal to non-existent.

=head1 METHODS

This class supports the following public methods:

=head2 new

 my $utdf = Astro::UTDF->new( raw_record => $buffer );

This method instantiates an Astro::UTDF object. You can pass name/value
pairs, where the name is the name of a mutator and the value is the
value to pass to it. If you pass no arguments, you get an object with
all attributes initialized to 0, except:

 front is initialized to its predefined value;
 router is initialized to '  ';
 tdrss_only is initialized to 18 null bytes;
 rear is initialized to its predefined value.

=head2 agc

 print 'AGC is ', $utdf->agc(), "\n";

This method returns the value of the AGC signal level at the receiver.

This information comes from bytes 39-40 of the record.

=head2 azimuth

 print 'Azimuth is ', $utdf->azimuth(), " radians\n";

This method returns the value of the antenna azimuth in radians.  If
L</enforce_validity> is true, this method will return C<undef> if
L</is_angle_valid> (bit 2 (from 0) of the L</data_validity> attribute)
is false.

This information comes from bytes 19-22 of the record.

=head2 clone

 my $clone = $utdf->clone();

This method returns a new object whose attributes are the same as those
of the object cloned. Be aware that this means
C<< $clone->prior_record() >> returns the same object as
C<< $utdf->prior_record() >> until you change one of them.

You can pass name/value pairs as arguments, in which case the names are
the names of mutator methods, and the arguments are arguments to them.
The mutators are called on the clone, not the original object.

If you call this as a static method, it is equivalent to L<new()|/new>.

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
If L</enforce_validity> is true, this method will return C<undef>
L</is_doppler_valid> (bit 1 (from 0) of the L</data_validity> attribute)
is false.

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

If L</enforce_validity> is true, this method will return C<undef> if
L</is_doppler_valid> (bit 1 (from 0) of the L</data_validity> attribute)
of either of the two records involved is false.

=head2 elevation

 print 'Elevation is ', $utdf->elevation(), " radians\n";

This method returns the elevation angle of the antenna, in radians.  If
L</enforce_validity> is true, this method will return C<undef> if
L</is_angle_valid> (bit 2 (from 0) of the L</data_validity> attribute)
is false.

This information comes from bytes 19-22 of the record.

=head2 enforce_validity

 print "Validity is ", $utdf->enforce_validity() ?
     " enforced\n" : " not enforced\n";
 $utdf->enforce_validity( 1 );

When called without an argument this method is an accessor, returning
the current value of the enforce_validity attribute.

When called with an argument this method is a mutator, setting the value
of the enforce_validity attribute and returning the mutated object.

The enforce_validity attribute is not part of the UTDF standard. If set
true (in the Perl sense, meaning any value but C<undef>, C<''> or C<0>),
those methods which return data having associated validity bits will
return C<undef> if the relevant validity bit is not set. If false, those
methods will ignore the validity bit and return whatever value the
attribute has.

This attribute defaults to C<undef> (that is, false).

=head2 frequency_band

 printf "Frequency band is 0x%01x\n",
     $utdf->frequency_band();
 $utdf->frequency_band( 3 );

When called without an argument, this method is an accessor returning
the frequency band encoded as a number from 0 to 15.

When called with an argument, this method is a mutator which sets the
frequency band to a number from 0 to 15; this number comes from the low
4 bits of the argument.

The frequency band is found in the high nybble of the
L</frequency_code_and_transmission_type>, and the encoding is documented
there.

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

=head2 hex_record

 print "The hexified record is ", $utdf->hex_record(), "\n";
 $utdf->hex_record('0d0a01 ... 040f0f' );

When called without an argument, this method is an accessor, returning
the L</raw_record> hexified by C<unpack 'H*'>.

When called with an argument, this method is a mutator, which generates
the raw record by C<pack 'H*'> and then passes that to L</raw_record>.

=head2 is_angle_valid

 print 'Angle data are ', (
     $utdf->is_angle_valid() ? '' : 'not' ), " valid\n";
 $utdf->is_angle_valid( 1 );

When called without an argument, this method is an accessor returning 1
(i.e. true) if angles are valid, and 0 (i.e. false) if not.

When called with an argument, this method is a mutator which sets the
angle validity to 1 if the argument is true and 0 if the argument is
false.

The angle data are considered valid if bit 2 (from 0) of
L<< $utdf->data_validity()|/data_validity >> is set.

=head2 is_doppler_valid

 print 'Doppler data are ', (
     $utdf->is_doppler_valid() ? '' : 'not' ), " valid\n";
 $utdf->is_doppler_valid( 1 );

When called without an argument, this method is an accessor returning 1
(i.e. true) if doppler counts are valid, and 0 (i.e. false) if not.

When called with an argument, this method is a mutator which sets the
doppler count validity to 1 if the argument is true and 0 if the
argument is false.

The doppler counts are considered valid if bit 1 (from 0) of
L<< $utdf->data_validity()|/data_validity >> is set.

=head2 is_range_valid

 print 'Range data are ', (
     $utdf->is_range_valid() ? '' : 'not' ), " valid\n";
 $utdf->is_range_valid( 1 );

When called without an argument, this method is an accessor returning 1
(i.e. true) if the range delay is valid, and 0 (i.e. false) if not.

When called with an argument, this method is a mutator which sets the
range delay validity to 1 if the argument is true and 0 if the argument
is false.

The range delay are considered valid if bit 0 (from 0) of
L<< $utdf->data_validity()|/data_validity >> is set.

=head2 is_last_frame

 print 'This is ', ( $utdf->is_last_frame() ? '' : 'not ' ),
     "the last frame\n";
 $utdf->is_last_frame( 1 );

When called without an argument, this method is an accessor returning 1
(i.e. true) if the last-frame bit is set, and 0 (i.e. false) if not.

When called with an argument, this method is a mutator which sets the
last-frame bit to 1 if the argument is true and 0 if the argument
is false.

The last-frame bit is bit 11 (from 0) of L</tracker_type_and_data_rate>.

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

=head2 prior_record

 my $prior = $utdf->prior_record();
 $utdf->prior_record( $another_record );

When called without any arguments, this method is an accessor which
returns the prior UTDF record. This is the record used to compute
L</doppler_shift> and from that L</range_rate>.

When called with an argument, this method is a mutator which sets the
prior UTDF record. The argument must be an Astro::UTDF object or
C<undef>. When called as an accessor, this method returns its object, so
that calls can be chained.

=head2 range_delay

 print 'Range delay ', $utdf->range_delay(), " nanoseconds\n";

This method returns the range delay (tracker to spacecraft to tracker)
in nanoseconds.  If L</enforce_validity> is true, this method will
return C<undef> if L</is_range_valid> (bit 0 (from 0) of the
L</data_validity> attribute) is false.

According to the specification the value returned by this method
includes transponder latency in the satellite, but not latency at the
ground station.

This information comes from bytes 27-32 of the record.

=head2 range_rate

 print 'Range rate ', $utdf->range_rate(), " km/second\n";

This method returns the range rate, or velocity in recession.

This is calculated from the Doppler shift, and will be C<undef> if
L</doppler_shift> returns C<undef>.

=head2 raw_record

 print 'Raw record in hex: ', unpack( 'H*', $utdf->raw_record() ), "\n";
 $utdf->raw_record( $buffer );

When called without an argument, this method is an accessor for the raw
UTDF record used to initialize the object. The returned datum will be 75
bytes long, in binary.

When called with an argument, this method is a mutator that sets the
object's attributes from the given raw record. This record should be
binary, 75 bytes long.

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
 my @data = Astro::UTDF->slurp(
     $file_name, attribute => $value ... );
 my @data = Astro::UTDF->slurp(
     file => $file_name, attribute => $value ... );

This static method reads the given file, returning an array of
Astro::UTDF objects. The argument can also be a handle to an open file.
The file will be put into C<binmode> and read to the end. Astro::UTDF
objects will be constructed from each of the records in the file, and
returned in the order they were read. All records but the first will
have their L</prior_record> attribute set to the previous record read.

You can also pass name/value pairs. These will be passed as arguments to
L<new()|/new> when the objects are created. If a value for an attribute
normally read from the file is specified, the given value will override
the value from the file.

If the number of arguments is odd, the first argument is taken to be the
file name or handle. You can also specify the file name or handle
explicitly with C<< Astro::UTDF->slurp( file => $file_name ); >>.

This method ignores the value of L</is_last_frame>.

=head2 tdrss_only

This method returns the 18 bytes of the record that are for Space
Network (TDRSS) use only.

This information comes from bytes 55-72 of the record.

=head2 tracker_type

 printf "Tracker type: 0x%01x\n", $utdf->tracker_type();
 $utdf->tracker_type( 1 );

When called without an argument, this method is an accessor returning
the tracker type encoded as a number from 0 to 15.

When called with an argument, this method is a mutator which sets the
tracker type to a number from 0 to 15; this number comes from the low
4 bits of the argument.

The tracker type is found in the high nybble of the
L</tracker_type_and_data_rate>, and the encoding is documented
there.

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
 $utdf->transmission_type( 4 );

When called without an argument, this method is an accessor returning
the transmission type encoded as a number from 0 to 15.

When called with an argument, this method is a mutator which sets the
transmission type to a number from 0 to 15; this number comes from the low
4 bits of the argument.

The transmission type is found in the low nybble of the
L</frequency_code_and_transmission_type>, and the encoding is documented
there.

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

# ex: set textwidth=72 :
