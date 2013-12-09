#!/usr/bin/perl
use strict;
use warnings;
use 5.10.0;
use XML::FeedPP;

my $url = shift || die "Usage: $0 URL <format string>";
my $format_string = shift || "__link__";

my $feed = XML::FeedPP->new($url);
my $rss_cache = rss2text::cache->new($url);

$rss_cache->get_cached_rss();
my $recent_pulled = $rss_cache->{w3c}->parse_datetime($feed->get_item(0)->pubDate());

# say each link if it's new
foreach my $item ( $feed->get_item() ) {
    last if (DateTime->compare($rss_cache->{last_pulled_dt}, $rss_cache->{w3c}->parse_datetime($item->pubDate())) > -1);
    say $item->link();
}

$rss_cache->update_rss_cache($recent_pulled);

### Cache class ###
package rss2text::cache;
use DateTime::Format::W3CDTF;
use Digest::MD5 'md5_hex';

sub new {
	my $class = shift;

	my $self->{url}    = shift;
	$self->{_cache_dir} = '/var/cache/rss2text/';
	$self->{_cache_filename} = $self->{_cache_dir} . md5_hex($self->{url});
	$self->{w3c} = DateTime::Format::W3CDTF->new;

	return bless $self, $class;
}

sub get_cached_rss {
	my $self = shift;

	mkdir $self->{_cache_dir}, 0755 unless (-e $self->{_cache_dir});

	unless (-e $self->{_cache_filename}) {
		print STDERR "Cache file for this feed doesn't exist.\n";
		print STDERR "Creating a new cache file and fetching from the beginning\n";
		open my $fh, '>', $self->{_cache_filename} or die "Can't create new cache file for this RSS feed: $!";
		$self->{last_pulled_dt} = DateTime->from_epoch(epoch => 0);
		return;
	}

	open my $fh, '<', $self->{_cache_filename} or die "Can't read the cached information for this RSS feed: $!";
	my $last_pulled_dt = <$fh>;
	unless ($last_pulled_dt) {
		print STDERR "Cache file for this feed is empty, starting from 0\n";
		$self->{last_pulled_dt} = DateTime->from_epoch(epoch => 0);
		return;
	}
	$self->{last_pulled_dt} = $self->{w3c}->parse_datetime($last_pulled_dt);
	return $self->{last_pulled_dt};
}

sub update_rss_cache {
	my ($self, $new_dt) = @_;

	# if the last_pulled_dt < $new_dt
	if (DateTime->compare($self->{last_pulled_dt}, $new_dt) == -1) {
		open my $fh, '>', $self->{_cache_filename} or die "Unable to update the cache file: $!";
		print $fh $self->{w3c}->format_datetime($new_dt);
		close $fh;
	}
}

