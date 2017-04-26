#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8 encode_utf8);
use English;
use HTML::TreeBuilder;
use LWP::UserAgent;
use URI;

# Don't buffer.
$OUTPUT_AUTOFLUSH = 1;

# URI of service.
my $base_uri = URI->new('http://www.sever.brno.cz/odbory.html');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite',
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

$dt->create_table(
    {'Odbor' => 'text',
    'Zkratka' => 'text'},
'data');
$dt->create_index(['Odbor'], undef, 'IF NOT EXISTS', 'UNIQUE');

# Get base root.
print 'Page: '.$base_uri->as_string."\n";
my $root = get_root($base_uri);

# Look for items.
my @h3 = $root->find_by_tag_name('h3');
foreach my $h3 (@h3) {
	my $department = $h3->as_text;
	if ($department =~ m/^Odbor/ms) {
		my $shortcut = dep_shortcut($department);
		print 'Department: '.encode_utf8($department)."\n";
		$dt->upsert({
			'Odbor' => $department,
			'Zkratka' => $shortcut,
		});
	}
}

# Get root of HTML::TreeBuilder object.
sub get_root {
	my $uri = shift;
	my $get = $ua->get($uri->as_string);
	my $data;
	if ($get->is_success) {
		$data = $get->content;
	} else {
		die "Cannot GET '".$uri->as_string." page.";
	}
	my $tree = HTML::TreeBuilder->new;
	$tree->parse(decode_utf8($data));
	return $tree->elementify;
}

# Get shortcut.
sub dep_shortcut {
	my $department = shift;
	my @chars = map { length $_ > 2 ? uc(substr($_, 0, 1)) : () }
		split m/\s+/ms, $department;
	return join '', @chars;
}

# Removing trailing whitespace.
sub remove_trailing {
	my $string_sr = shift;
	${$string_sr} =~ s/^\s*//ms;
	${$string_sr} =~ s/\s*$//ms;
	return;
}
