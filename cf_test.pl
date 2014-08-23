#!/usr/bin/perl

use warnings;
use strict;

use lib q{/home/sauer/dev/parse-cfengine/lib};
use Parse::CFEngine;

my $path = shift
  or die qq{Usage: $0 filename\n};
my $parser = Parse::CFEngine->new();
$parser->parse_file( $path );
$parser->junk();
