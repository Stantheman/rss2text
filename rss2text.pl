#!/usr/bin/perl
use strict;
use warnings;
use 5.10.0;
use LWP::UserAgent;
use XML::FeedPP;

my $url = shift || die "Usage: $0 URL <format string>";
my $format_string = shift || "__link__";

# get everything we know about this url
my $rss_cache = rss2text::cache->new($url);
$rss_cache->get_cached_rss();

# get everything the internet knows about this url
my $feed = get_xml_feed($url, $rss_cache);

# get the date of the newest entry
my $recent_pulled = $rss_cache->{w3c}->parse_datetime($feed->get_item(0)->pubDate());

# say each link if it's new
foreach my $item ( $feed->get_item() ) {
    last if (DateTime->compare($rss_cache->{last_pulled_dt}, $rss_cache->{w3c}->parse_datetime($item->pubDate())) > -1);
	(my $output = $format_string) =~ s/__([^\s]*?)__/$item->get($1) ? $item->get($1) : "TAG \"$1\" UNDEFINED"/ge;
	say $output;
}

$rss_cache->update_rss_cache($recent_pulled);

sub get_xml_feed {
	my ($url, $rss_cache) = @_;
	my $ua = LWP::UserAgent->new();

	# add caching headers if they exist
	if (length($rss_cache->{etag})) {
		$ua->default_header('If-None-Match' => '"' . $rss_cache->{etag} . '"');
	}
	if (length($rss_cache->{last_modified})) {
		$ua->default_header('If-Modified-Since' => '"' . $rss_cache->{last_modified} . '"');
	}

	my $rss_feed = $ua->get($url);

	# nothing to do if it hasn't been modified
	exit 0 if ($rss_feed->code() == 304);

	if ($rss_feed->is_error()) {
		print STDERR "$url returned " . $rss_feed->code() . "bailing\n";
		exit 1;
	}

	return XML::FeedPP->new($rss_feed->decoded_content);
}

### Cache class ###
package rss2text::cache;
use DateTime::Format::W3CDTF;
use Digest::MD5 'md5_hex';

sub new {
	my $class = shift;

	my $self->{url}    = shift;
	$self->{_cache_dir} = '/tmp/rss2text/';
	$self->{_cache_filename} = $self->{_cache_dir} . md5_hex($self->{url});
	$self->{w3c} = DateTime::Format::W3CDTF->new;

	$self->{etag} = '';
	$self->{last_modified} = '';
	$self->{last_pulled_dt} = DateTime->from_epoch(epoch => 0);

	return bless $self, $class;
}

sub get_cached_rss {
	my $self = shift;

	mkdir $self->{_cache_dir}, 0755 unless (-e $self->{_cache_dir});
	die "Unable to make $self->{_cache_dir}: $!" unless (-e $self->{_cache_dir});

	unless (-e $self->{_cache_filename}) {
		print STDERR "Cache file for this feed doesn't exist.\n";
		print STDERR "Creating a new cache file and fetching from the beginning\n";
		open my $fh, '>', $self->{_cache_filename} or die "Can't create new cache file for this RSS feed: $!";
		return;
	}

	open my $fh, '<', $self->{_cache_filename} or die "Can't read the cached information for this RSS feed: $!";
	my $last_pulled_dt = <$fh>;
	unless ($last_pulled_dt) {
		print STDERR "Cache file for this feed is empty, starting from 0\n";
		return;
	}
	$self->{last_pulled_dt} = $self->{w3c}->parse_datetime($last_pulled_dt);
	chomp($self->{etag} = <$fh>);
	chomp($self->{last_modified} = <$fh>);
	return $self->{last_pulled_dt};
}

sub update_rss_cache {
	my ($self, $new_dt) = @_;

	# if the last_pulled_dt < $new_dt
	if (DateTime->compare($self->{last_pulled_dt}, $new_dt) == -1) {
		open my $fh, '>', $self->{_cache_filename} or die "Unable to update the cache file: $!";
		print $fh $self->{w3c}->format_datetime($new_dt) . "\n";
		print $fh $self->{etag} . "\n";
		print $fh $self->{last_modified} . "\n";
		close $fh;
	}
}

__END__

=head1 rss2text

Takes a feed and optional format string, and prints for every new entry.

=head1 USAGE

	./rss2text.pl URL
	./rss2text.pl URL "__title__: __link__"

=head1 DESCRIPTION

rss2text takes a feed and an optional format string, grabs the feed and loops
over the returned entries, printing what was requested in the format string.
It's like printf for RSS feeds and is particularly useful for one-liners and
other places you need a textual interface.

rss2text assumes a format string of "__link__", which will loop over entries
and print the URL for each entry.

By default, rss2text caches hits to the URL under /tmp/rss2text. If a
cached file is available, it will read it and only loop over entries newer
than the last time it ran. This makes rss2text especially useful for cronjobs.

The format string can takes any child elements that belong in an entry. Typical
entries include "title", "description", "published", "link", and "author".

You can request anything you'd like if you know that a feed will have the item
you're requesting. If it's not there, you'll get a big pretty message placeholder
in your output:

	TAG "thing" UNDEFINED

Check your placeholders!

=head1 DEPENDENCIES

rss2text is written in perl and uses LWP::UserAgent to grab feeds, XML::FeedPP
for parsing feeds, and DateTime::Format::W3CDTF to parse dates.

Debian has packages available each:

	apt-get install libwww-perl libxml-feedpp-perl libdatetime-format-w3cdtf-perl

rss2text uses perl 5.10.0. Older perls can be used, but you'll have to do the
say/print-newline dance yourself.

=head1 EXAMPLES

	# print a list of new links from the feed
	./rss2text.pl http://www.schwertly.com/feed/

	# print a list of titles from the feed
	./rss2text.pl http://www.schwertly.com/feed/ "__title__"

=head1 AUTHOR

Stan Schwertly (http://www.schwertly.com)

