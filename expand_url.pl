# expand_url_privmsgs
#   ON  -> Expand URLs in private messages (This is the default)
#   OFF -> Do NOT expand URLs in private messages
# expand_url_whitelist
#   A whitespace delimited list of channels where we want to expand URLs sent
#   to us. If left undefined, URLs sent to all channels will be expanded.
#   This is undefined by default.

use Irssi;
use Irssi::TextUI;
use strict;
use LWP;
use LWP::UserAgent;
use URI::Escape;
use vars qw($VERSION %IRSSI);

# TODO If you have any ideas, send 'em in!
# Is a whitelist necessary?

$VERSION = '0.2';
%IRSSI = (
    authors     => 'Jared Candelaria',
    contact     => 'jcande@github',
    name        => 'Expand URL',
    description => 'Expand shortened URLs into something readable.',
    license     => 'BSD',
    url         => 'http://',
    changed     => '2011-08-14',
);

Irssi::settings_add_bool('expand_url', 'expand_url_privmsgs', 1);
Irssi::settings_add_str('expand_url', 'expand_url_white', undef);

my $ua = LWP::UserAgent->new;
$ua->agent("Expand URL irssi script () ");
$ua->timeout(15);

sub message_public {
	my ($server, $msg, $nick, $address, $target) = @_;
	my $new_msg;

	if (whitelisted($target)) {
		$new_msg = message($msg);
	} else {
		$new_msg = $msg;
	}

	Irssi::signal_continue($server, $new_msg, $nick, $address, $target);
}
sub message_private {
	my ($server, $msg, $nick, $address) = @_;
	my $new_msg;

	if (Irssi::settings_get_bool('expand_url_privmsgs')) {
		$new_msg = message($msg);
	} else {
		$new_msg = $msg;
	}

	Irssi::signal_continue($server, $new_msg, $nick, $address);
}
sub message_topic {
	my ($server, $channel, $topic, $nick, $address) = @_;
	my $new_topic;

	if (whitelisted($channel)) {
		$new_topic = message($topic);
	} else {
		$new_topic = $topic;
	}

	Irssi::signal_continue($server, $channel, $new_topic, $nick, $address);
}
sub message_part {
	my ($server, $channel, $nick, $address, $reason) = @_;
	my $new_reason;

	if (whitelisted($channel)) {
		$new_reason = message($reason);
	} else {
		$new_reason = $reason;
	}

	Irssi::signal_continue($server, $channel, $nick, $address, $new_reason);
}
sub message_quit {
	my ($server, $nick, $address, $reason);
	# We expand quit messages and have no knob to tell us not to.
	my $new_reason = message($reason);

	Irssi::signal_continue($server, $nick, $address, $new_reason);
}

sub whitelisted {
	my ($channel) = @_;
	my $whitelist = Irssi::settings_get_str('expand_url_white');

	# If our whitelist is undefined, we assume all channels are
	# acceptable.
	if ($whitelist eq undef) {
		return 1;
	}

	my @chans = split(' ', $whitelist);

	# Otherwise, make sure our channel is on the list.
	foreach my $chan (@chans) {
		if ($channel eq $chan) {
			return 1;
		}
	}
	return 0;
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

Irssi::signal_add_last("message public", "message_public");
Irssi::signal_add_last("message private", "message_private");
Irssi::signal_add_last("message topic", "message_topic");
Irssi::signal_add_last("message part", "message_part");
Irssi::signal_add_last("message quit", "message_quit");
