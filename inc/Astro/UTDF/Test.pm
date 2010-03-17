package Astro::UTDF::Test;

use strict;
use warnings;

use base qw{ Exporter };

use Carp;
use Test::More 0.40;

my @export = qw{
    decode
    fails
    hexify
    returns
    round_trip
};

our @EXPORT = ( @export, @Test::More::EXPORT );
our @EXPORT_OK = ( @export, @Test::More::EXPORT_OK );

sub decode {
    splice @_, 1, 0, 'decode';
    goto &returns;
}

sub fails {	## no critic (RequireArgUnpacking)
    my ( $obj, @args ) = @_;
    my $opt = ref $args[0] eq 'HASH' ? shift @args : {};
    my $method = shift @args;
    my $name = pop @args;
    my $want = pop @args;
    ref $want or $want = qr<@{[ quotemeta $want ]}>;
    local $@;
    eval { $obj->$method( @args ); 1 }
	and do {
	@_ = ( "$name did not throw an exception" );
	goto &fail;
    };
    @_ = ( $@, $want, $name );
    goto &like;
}

sub hexify {
    splice @_, 1, 0, { unpack => 'H*' };
    goto &returns;
}

sub returns {	## no critic (RequireArgUnpacking)
    my ( $obj, @args ) = @_;
    my $opt = ref $args[0] eq 'HASH' ? shift @args : {};
    my $method = shift @args;
    my $name = pop @args;
    my $want = pop @args;
    my $got;
    eval { $got = $obj->$method( @args ); 1 }
	or do {
	@_ = ( "$name threw $@" );
	goto &fail;
    };
    $opt->{unpack}
	and $got = unpack $opt->{unpack}, $got;
    $opt->{sprintf}
	and $got = sprintf $opt->{sprintf}, $got;
    @_ = ( $got, $want, $name );
    goto &is;
}

sub round_trip {	## no critic (RequireArgUnpacking)
    my ( $attr, $value, $opt ) = @_;
    $opt ||= {};
    my $name = "Round-trip $attr( $value )";
    my $utdf = eval {
	my $obj = Astro::UTDF->new( $attr => $value );
	return Astro::UTDF->new( raw_record => $obj->raw_record() );
    } or do {
	@_ = ( "$name threw $@" );
	goto &fail;
    };
    @_ = ( $utdf, $opt, $attr, $value, $name );
    goto &returns;
}

1;

=head1 NAME

Astro::UTDF::Test - <<< replace boilerplate >>>

=head1 SYNOPSIS

<<< replace boilerplate >>>

=head1 DETAILS

<<< replace boilerplate >>>

=head1 METHODS

This class supports the following public methods:

=head1 ATTRIBUTES

This class has the following attributes:


=head1 SEE ALSO

<<< replace or remove boilerplate >>>

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010, Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

__END__

# ex: set textwidth=72 :
