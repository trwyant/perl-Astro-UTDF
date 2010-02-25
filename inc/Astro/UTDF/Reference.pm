package Astro::UTDF::Reference;

use strict;
use warnings;

use Bit::Vector;
use Carp;
use Readonly;

{

    my $previous_object;

    sub new {
	my ( $class, $data ) = @_;
	ref $class and $class = ref $class;
	my $self = {
	    previous_object	=> $previous_object,
	};
	if ( length $data == 75 ) {
	    $self->{hex_data} = unpack 'H*', $data;
	} elsif ( length $data == 150 ) {
	    $self->{hex_data} = $data;
	} else {
	    croak 'Data wrong length. Must be 75 bytes (raw) or 150 bytes',
	       ' (hexified)';
	}
	bless $self, $class;
	$previous_object = $self;
	return $self;
    }

}

sub doppler_count {
    my ( $self ) = @_;
    exists $self->{doppler_count} and return $self->{doppler_count};
    my $utdf_uncoded = $self->{hex_data};
    my $fd = substr($utdf_uncoded, 64, 12);
    my $vec = Bit::Vector->new_Hex(64, "$fd");
    $fd = $vec->to_Dec();
    return ( $self->{doppler_count} = $fd );
}

sub doppler_mode {
    my ( $self ) = @_;
    exists $self->{doppler_mode} and return $self->{doppler_mode};
    my $utdf_uncoded = $self->{hex_data};
    my $packed_words = sprintf("%d", hex(substr($utdf_uncoded, 96, 2)));
    my $doppler_mode = sprintf("%b", $packed_words);
    $doppler_mode = oct("0b$doppler_mode");
    if ($doppler_mode eq 2)
    {
	$doppler_mode = 1;
    }
    else
    {
	$doppler_mode = 2;
    }
    return ( $self->{doppler_mode} = $doppler_mode );
}

sub doppler_valid {
    my ( $self ) = @_;
    exists $self->{doppler_valid} and return $self->{doppler_valid};
    my $status_byte = hex( substr $self->{hex_data}, 100, 2 );
    return ( $self->{doppler_valid} = ( $status_byte & 0x02 ? 1 : 0 ) );
}

sub frequency {
    my ( $self ) = @_;
    exists $self->{frequency} and return $self->{frequency};
    my $utdf_uncoded = $self->{hex_data};
    return ( $self->{frequency} =
	(sprintf("%d", hex(substr($utdf_uncoded, 80, 8)))) * 10 );
}

sub previous_object {
    my ( $self ) = @_;
    return $self->{previous_object};
}

sub range_delay {
    my ( $self ) = @_;
    exists $self->{range_delay} and return $self->{range_delay};
    my $utdf_uncoded = $self->{hex_data};
    my $range_value = substr($utdf_uncoded, 54, 10);
    my $vec = Bit::Vector->new_Hex(64, "$range_value");
    $range_value = $vec->to_Dec();
    return ( $self->{range_delay} = $range_value );
}

sub ranging_valid {
    my ( $self ) = @_;
    exists $self->{ranging_valid} and return $self->{ranging_valid};
    my $status_byte = hex( substr $self->{hex_data}, 100, 2 );
    return ( $self->{ranging_valid} = ( $status_byte & 0x01 ? 1 : 0 ) );
}

sub time : method {
    my ( $self ) = @_;
    exists $self->{time} and return $self->{time};
    my $utdf_uncoded = $self->{hex_data};
    return ( $self->{time} = sprintf("%d", hex(substr($utdf_uncoded, 20, 8))) );
}

Readonly::Scalar my $lightspeed => 299792.458;

sub doppler
{
    my ( $self ) = @_;				#TW

    #
    # Subroutine that will extract doppler measurements from utdf file
    #

#TW if ($_[1] != 1)
    if ( ! $self->doppler_valid() )		#TW
    {

#TW     # Ranging not valid, return zero
#TW     return sprintf "%6s.%014s", 0, 0;
	# Doppler not valid, return undef	#TW
	return;					#TW
    }
    else
    {
#TW     my $utdf_uncoded = $_[0];
	my $utdf_uncoded = $self->{hex_data};	#TW

#TW     my $freq = (sprintf("%d", hex(substr($utdf_uncoded, 80, 8)))) * 10;
	my $freq = $self->frequency();		#TW
#TW     my $time         = sprintf("%d", hex(substr($utdf_uncoded, 20, 8)));
	my $time         = $self->time();
#TW     my $packed_words = sprintf("%d", hex(substr($utdf_uncoded, 96, 2)));
#TW     my $doppler_mode = sprintf("%b", $packed_words);
#TW     $doppler_mode = oct("0b$doppler_mode");
#TW     if ($doppler_mode eq 2)
#TW     {
#TW         $doppler_mode = 1;
#TW     }
#TW     else
#TW     {
#TW         $doppler_mode = 2;
#TW     }
	my $doppler_mode = $self->doppler_mode();

#TW     my $fd = substr($utdf_uncoded, 64, 12);
#TW     my $vec = Bit::Vector->new_Hex(64, "$fd");
#TW     $fd = $vec->to_Dec();
	my $fd = $self->doppler_count();		#TW

	my $previous_object = $self->previous_object()	#TW
	    or return;					#TW
	my $previous_fd = $previous_object->doppler_count();	#TW
	my $previous_time = $previous_object->time();	#TW

#        my $rr = (
#             -$lightspeed * (
#                 (($fd - $previous_fd) / ($time - $previous_time)) - 240000000
#             )
#        ) / (2 * $freq * (240 / 221) * 1000);

        #my $rr = ( -$lightspeed * ((($fd - $previous_fd) / ($time - $previous_time)) - 240000000)) / (2 * $freq * (240 / 221) * 1000) * -1;
        my $rr = ( $lightspeed * ((($fd - $previous_fd) / ($time - $previous_time)) - 240000000)) / (2 * $freq * (240 / 221) * 1000);
	return sprintf '% 21.14f', -$rr;	#TW
        my $rr_first = $1 if ($rr =~ /(.[0-9]*)\.\d*/);
        my $rr_last  = $1 if ($rr =~ /.\d*\.(\d*)/);
        $rr_last = "$rr_last" . "00000000000000";
        $rr_last = $1 if ($rr_last =~ /(\d{14})/);

        $previous_fd   = $fd;
        $previous_time = $time;

        return sprintf "% 6d.%08s", $rr_first, $rr_last;
    }
}    # end DOPPLER



sub ranging
{
    my ( $self ) = @_;				#TW

    #
    # Subroutine that will extract ranging measurements from utdf file
    #

#TW if ($_[1] != 1)
    if ( $self->ranging_valid() )		#TW
    {

#TW     # Ranging not valid, return zero
#TW     return sprintf "%6s.%014s", 0, 0;
	# Ranging not valid, return undef
	return;
    }
    else
    {
#TW     my $utdf_uncoded = $_[0];

#TW     my $range_value = substr($utdf_uncoded, 54, 10);
#TW     my $vec = Bit::Vector->new_Hex(64, "$range_value");
#TW     $range_value = $vec->to_Dec();
	my $range_value = $self->range_delay();	#TW

        my $station_delay = (77934 * 256);
        $range_value = $range_value - $station_delay;

        my $mellom = ($lightspeed / 512000000000000)
            * $range_value;    # Using correct lightspeed

        my $range_km = $1 if ($mellom =~ /([0-9]*).[0-9]*/);
        $range_km = "000000" . "$range_km";
        $range_km = $1 if ($range_km =~ /\d*(\d{6})/);
        my $range_m = $1 if ($mellom =~ /[0-9]*.([0-9]*)/);
        $range_m = "$range_m" . "00000000000000";
        $range_m = $1 if ($range_m =~ /(\d{14})/);

        return sprintf "%6s.%014s", $range_km, $range_m;

    }
}    # end RANGING

1;

=head1 NAME

Astro::UTDF::Reference - Reference UTDF object

=head1 SYNOPSIS

 my $ref = Astro::UTDF::Reference->new( $utdf_record );
 my $rng = $ref->ranging();
 defined $rng or $rng = 'undef';
 print "Range is $rng\n";

=head1 DETAILS

This class represents a record from a Universal Tracking Data Format
data file. The objects must be instantiated in the order the records
appear in the file.

The guts are by Vidar Hansen. The object oriented wrapping is by Tom
Wyant.

=head1 METHODS

This class supports the following public methods:

=head2 new

 my $ref = Astro::UTDF::Reference->new( $utdf_record );

This method makes a new object out of the given record. Note that
Doppler shift and associated data are derived from the difference
between successive Doppler counts. So the objects must be instantiated
in order.

The C<$utdf_record> can be either raw, or already hexified.

This method is by Tom Wyant.

=head2 doppler

 my $rr = $ref->doppler();
 print "Range rate is ", defined $rr ? "$rr\n" : "undef\n";

This method returns the range rate for the datum. It will return undef
for the first object instantiated, or if C<< $ref->doppler_valid() >> is
false. The guts are by Vidar Hansen, the o-o boiler plate and the
replacement of in-situ calculation by accessor methods are by Tom Wyant.

=head2 doppler_count

 my $dc = $ref->doppler_count();
 print "Doppler count is ", defined $dc ? "$dc\n" : "undef\n";

This method returns the Doppler count for the datum. It will return
undef if C<< $ref->doppler_valid() >> is false. The guts are by Vidar
Hansen, the o-o boiler plate by Tom Wyant.

=head2 doppler_mode

 print "Doppler mode is ", $ref->doppler_mode(), "\n";

This method displays the Doppler mode. The guts are by Vidar Hansen, the
o-o boiler plate is by Tom Wyant.

=head2 doppler_valid

 print "Doppler datum is ", $ref->doppler_valid() ?
     "valid\n" : "not valid\n";

This method returns a true value if the Doppler datum of the record is
valid, and false otherwise. It is by Tom Wyant.

=head2 frequency

 print "Frequency is ", $ref->frequency(), "\n";

This method returns the frequency. The guts are by Vidar Hansen, and the
o-o boiler plate by Tom Wyant.

=head2 range_delay

 print "The range delay is ", $ref->range_delay(),
     " 256ths of a nanosecond\n";

This method returns the range delay in 256ths of a nanosecond (i.e.
divide by 256 to get nanoseconds). If C<< $ref->ranging_valid() >>
returns false, this method will return undef. The guts are by Vidar
Hansen, and the o-o boiler plate by Tom Wyant.

=head2 ranging

 print "The range is ", $ref->ranging(), "\n";

This method returns the range in kilometers. If the
C<< $ref->ranging_valid() >> method returns false, this method will
return undef.

The guts are by Vidar Hansen, the o-o boiler plate and the replacement
of in-situ calculation by accessor methods are by Tom Wyant.

=head2 ranging_valid

 print "Doppler datum is ", $ref->doppler_valid() ?
     "valid\n" : "not valid\n";

This method returns a true value if the ranging datum of the record is
valid, and false otherwise. It is by Tom Wyant.

=head2 time

This method returns the time since the start of the year, in seconds.
The guts are by Vidar Hansen, and the o-o boiler plate by Tom Wyant.


=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Vidar Hansen and
Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010, Vidar Hansen and Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

__END__

# ex: set textwidth=72 :
