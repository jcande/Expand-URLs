use Irssi;
use Irssi::TextUI;
use strict;
use LWP;
use LWP::UserAgent;
use URI::Escape;
use vars qw($VERSION %IRSSI);

# TODO Only expand URLs in certain channels.

$VERSION = '0.2';
%IRSSI = (
    authors     => 'Jared Candelaria',
    contact     => 'napum@demigods.org',
    name        => 'expand_url.pl',
    description => 'Expand shortened URLs into something readable.',
    license     => 'BSD',
    url         => '',
    changed     => '2011-08-14',
);

my $ua = LWP::UserAgent->new;
$ua->agent("Expand URL irssi script (jsc\@demigods.org) ");
$ua->timeout(15);

sub message_public {
	my ($server, $msg, $nick, $address, $target) = @_;
	my $new_msg = message($msg);

	Irssi::signal_continue($server, $new_msg, $nick, $address, $target);
}
sub message_private {
	my ($server, $msg, $nick, $address) = @_;
	my $new_msg = message($msg);

	Irssi::signal_continue($server, $new_msg, $nick, $address);
}
sub message_topic {
	my ($server, $channel, $topic, $nick, $address) = @_;
	my $new_topic = message($topic);

	Irssi::signal_continue($server, $channel, $new_topic, $nick, $address);
}

sub parse {
	my ($json) = @_;
	# Instead of using a JSON parser, we exploit
	# the fact the our responses are mostly the same.
	# XXX This is not the best idea.
	# NOTE Reponse: {"long-url":"URL"}
	my $len = length($json);
	my $URL = substr($json, 13, $len - 13 - 2);

	# Turn \/ into /, among other things (unquotemeta from CPAN).
	$URL =~ s/(?:\\(?!\\))//g;
	$URL =~ s/(?:\\\\)/\\/g;

	return uri_unescape($URL);
}

sub expand {
	my $longurl = 'http://api.longurl.org/v2/expand?format=json&url=';

	my ($URL) = @_;
	my $enc = uri_escape($URL);

	my $req = HTTP::Request->new('GET');
	$req->url($longurl . $enc);

	my $response = $ua->request($req);

	# We've got an error. Return the original URL.
	if ($response->code != 200) {
		return $URL;
	}

	return parse($response->content);
	# Percent encode $URL, call longurl, parse output, return parsed
}

# This is where the magic happens.
sub message {
	my ($msg) = @_;
	# Split $msg into an array delimited by spaces.
	# Check each element for ^http:// or ^https://
	# If it matches, replace it with the response from longurl's API
	# 	Unless there's an error
	# Collapse the array back into a single value and return it

	my @values = split(' ', $msg);
	foreach my $val (@values) {
		if ($val =~ /^https?:\/\/.*/) {
			$val = expand($val);
		}
	}
	return join(' ', @values);
}

Irssi::signal_add("message public", "message_public");
Irssi::signal_add("message private", "message_private");
Irssi::signal_add("message topic", "message_topic");
