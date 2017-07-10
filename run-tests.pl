#!/usr/bin/env perl

use strict;
use warnings;

use Cwd qw( cwd );
use File::Find;

my $luajit_prefix = shift or
	die "no luajit installation prefix specified.\n";

my $valgrind = shift;

my $luajit = glob "$luajit_prefix/bin/luajit*";

if (!$luajit || !-x $luajit) {
	die "cannot find the luajit binary under $luajit_prefix/bin/";
}

if ($valgrind) {
	$luajit = "valgrind --num-callers=100 --leak-check=full --show-possibly-lost=no -q $luajit";
}

my $luajit_inc = "$luajit_prefix/include/luajit-2.1";

my $failures = 0;

sub shell {
	my ($cmd, $test) = @_;
	if (system("@_") != 0) {
		if ($test) {
			warn "\e[31mFailed test when running @_: $?\e[0m\n";
			$failures++;
		} else {
			die "cannot run command @_: $?\n";
        }
	}
}

sub wanted {
	return unless -f $_ && /\.lua$/;
	return if $_ eq 'ffi_arith_int64.lua';
	warn "=== $File::Find::name\n";
	shell("$luajit $_", 1);
}

shell "cd test/clib && rm -f ctest && gcc -O -g -o ctest -fpic -shared -I $luajit_inc ctest.c";
shell "cd test/clib && rm -f cpptest && g++ -O -g -o cpptest -fpic -shared -I $luajit_inc cpptest.cpp";

my $cwd = cwd();

$ENV{LUA_CPATH} = "$cwd/test/clib/?;;";

my $cmd = "pkg-config --cflags --libs gtk+-2.0";
my $cdefs = `$cmd`;
if ($? != 0) {
	die "failed to run command $cmd: $?";
}
chomp $cdefs;
$ENV{CDEFS} = $cdefs;


find({ wanted => \&wanted }, 'test');
#find({ wanted => \&wanted }, 'bench');

if ($failures) {
    print "\e[31m$failures tests failed.\e[0m\n";
} else {
    print "\e[32mAll tests successful.\e[0m\n";
}
