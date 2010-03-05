use strict;
use warnings;

use 5.006;

use lib qw{ inc };

use Module::Build;
use My::Module::Build;

(my $mbv = Module::Build->VERSION()) =~ s/_//g;
my %args = (
    dist_author => 'Tom Wyant (wyant at cpan dot org)',
    dist_abstract => 'Represent Universal Tracking Data Format (UTDF) data',
    module_name => 'Astro::UTDF',
    build_requires => {
	'Test::More' => 0.40,
    },
    requires => {
	'Params::Util'	=> 0.25,
	'Scalar::Util'	=> 0,
	perl		=> 5.006,
    },
    license => 'perl',
);

$mbv >= 0.28 and $args{meta_merge} = {
    no_index => {
	directory => [qw{inc t xt}],
    },
};

$mbv >= 0.34
    and $args{auto_configure_requires} = 0;	# Don't require Module::Build

my $bldr = My::Module::Build->new (%args);

$bldr->create_build_script ();
