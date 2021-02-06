package main;

use 5.010;

use strict;
use warnings;

use Test::More 0.88;	# Because of done_testing();

eval {
    require Test::Prereq::Meta;
    1;
} or plan skip_all => 'Test::Prereq::Meta not available';

Test::Prereq::Meta->new(
)->all_prereq_ok();

done_testing;

1;

# ex: set textwidth=72 :
