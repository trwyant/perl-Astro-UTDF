use strict;
use warnings;

use ExtUtils::MakeMaker;

(my $mmv = ExtUtils::MakeMaker->VERSION) =~ s/_//g;

my %args = (
    NAME => 'Astro::UTDF',
    VERSION_FROM => 'lib/Astro/UTDF.pm',
    PREREQ_PM => {
	'Params::Util'	=> 0.25,
    },
    PL_FILES => {},	# Prevent old MakeMaker from running Build.PL
    'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
    AUTHOR => 'Tom Wyant (wyant at cpan dot org)',
    ABSTRACT => 'Represent Universal Tracking Data Format (UTDF) data',
);

$mmv >= 6.31 and $args{LICENSE} = 'perl';

$mmv >= 6.4501 and $args{META_ADD} = {
    no_index => {
	directory => [ qw{ inc t xt } ],
    },
};

$mmv >= 6.4501 and $args{META_MERGE} = {
    build_requires => {
	'Test::More' => 0.40,
    },
    resources => {
	license => 'http://dev.perl.org/licenses/',
    },
}

WriteMakefile (%args);

