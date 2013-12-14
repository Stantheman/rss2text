#!/usr/bin/perl
use strict;
use warnings;
use 5.10.0;
use Getopt::Long qw(:config auto_help);
use LWP::UserAgent;
use Pod::Usage;
use Try::Tiny;
use XML::FeedPP;

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

# get options passed in
my ($opts, $url) = get_options();

# get everything we know about this url
my $rss_cache = rss2text::cache->new($url, $opts->{cache}, $opts->{cache_dir});
$rss_cache->get_cached_rss();

# get everything the internet knows about this url
my $feed = get_xml_feed($url, $rss_cache);

# get the date of the newest entry
my $recent_pulled = $rss_cache->{w3c}->parse_datetime($feed->get_item(0)->pubDate());

# say each link if it's new
foreach my $item ( $feed->get_item() ) {
	last if ($rss_cache->is_cached_newer($item->pubDate()));

	(my $output = $opts->{format}) =~ s/__([^\s]*?)__/parse_token($item, $1)/ge;
	say $output;
}

$rss_cache->update_rss_cache($recent_pulled);

sub get_options {
	# default settings
	my %opts = (
		format    => '__link__',
		cache     => 1,
		cache_dir => '/tmp/rss2text/',
	);

	GetOptions(\%opts,
		'format|f:s',
		'cache|c!',
		'cache_dir:s',
	) or pod2usage(2);

	my $url = shift @ARGV or pod2usage(2);

	# expand newlines and tabs using cool double eval
	$opts{format} =~ s/\\([nt])/"qq|\\$1|"/gee;

	# add a trailing slash if they forgot
	$opts{cache_dir} =~ s|([^/])$|$1/|;

	return (\%opts, $url);
}

sub get_xml_feed {
	my ($url, $rss_cache) = @_;
	my $ua = LWP::UserAgent->new(
		agent => 'rss2text (https://github.com/Stantheman/rss2text)',
	);

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

	my $feed;
	try {
		$feed = XML::FeedPP->new($rss_feed->decoded_content);
	} catch {
		print STDERR "$url is not in valid RSS format: ", $_;
		exit 1;
	};

	return $feed;
}

sub parse_token {
	my ($item, $token) = @_;

	# XML::FeedPP will work harder for us if we use their convenience functions instead of get
	if ($item->can($token)) {
		return $item->$token();
	}
	# otherwise, try to get
	my $token_val = $item->get($token);
	unless ($token_val) {
		return "TAG \"$token\" UNDEFINED";
	}
	return $token_val;
}

### Cache class ###
package rss2text::cache;
use DateTime::Format::W3CDTF;
use Digest::MD5 'md5_hex';
use Try::Tiny;

sub new {
	my ($class, $url, $cache_on, $cache_dir) = @_;

	my $self->{url}   = shift;
	$self->{_cache_on} = $cache_on;
	
	$self->{_cache_dir} = $cache_dir;
	$self->{_cache_filename} = $self->{_cache_dir} . md5_hex($< . $self->{url});
	$self->{w3c} = DateTime::Format::W3CDTF->new;

	$self->{etag} = '';
	$self->{last_modified} = '';
	$self->{last_pulled_dt} = DateTime->from_epoch(epoch => 0);

	return bless $self, $class;
}

sub get_cached_rss {
	my $self = shift;

	return unless $self->{_cache_on};

	mkdir $self->{_cache_dir}, 0755 unless (-e $self->{_cache_dir});
	die "Unable to make $self->{_cache_dir}: $!" unless (-e $self->{_cache_dir});

	unless (-e $self->{_cache_filename}) {
		print STDERR "Cache file for this feed doesn't exist.\n";
		print STDERR "Creating a new cache file and fetching from the beginning\n";
		open my $fh, '>', $self->{_cache_filename} or die "Can't create new cache file for this RSS feed: $!";
		return;
	}

	open my $fh, '<', $self->{_cache_filename} or die "Can't read the cached information for this RSS feed: $!";
	chomp(my $last_pulled_dt = <$fh>);
	unless ($last_pulled_dt) {
		print STDERR "Cache file for this feed is empty, starting from 0\n";
		return;
	}

	# parse_datetime might die
	try {
		$last_pulled_dt = $self->{w3c}->parse_datetime($last_pulled_dt);
	} catch {
		print STDERR "Cached pull date isn't valid: $last_pulled_dt. Using 0\n";
		$last_pulled_dt = $self->{last_pulled_dt};
	};

	$self->{last_pulled_dt} = $last_pulled_dt;

	chomp($self->{etag} = <$fh>);
	chomp($self->{last_modified} = <$fh>);
	return $self->{last_pulled_dt};
}

sub is_cached_newer {
	my ($self, $compare_dt) = @_;

	return unless $self->{_cache_on};

	return (DateTime->compare($self->{last_pulled_dt}, $self->{w3c}->parse_datetime($compare_dt)) >= 0);
}

sub update_rss_cache {
	my ($self, $new_dt) = @_;

	return unless $self->{_cache_on};

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
	./rss2text.pl --format "__title__: __link__" URL

=head1 SYNOPSIS

	./rss2text [options] URL

	Options:
	  -f, --format          template string for returning results.
	  -[no]c, --[no]cache   enables/disables cache.
	  --cache-dir           location of the cache directory.

=head1 OPTIONS

=item B<-f> I<format string>, B<--format>=I<format string>

The format string dictates how rss2text returns your data. It can include any
static text you'd like along with placeholders, which use double underscores
to separate themselves. A placeholder looks like __name__ and will be substituted
with the child element of the feed entry. 

The format string can take any child elements that belong in an entry. Typical
placeholders include "title", "description", "published", "link", and "author".
Printing the title of every link is achieved by passing in the format string as
"__title__". If you want to print the title, a colon and a single
space, and then the link, simply pass "__title__: __link__".

You can request anything you'd like if you know that a feed will have the item
you're requesting. If it's not there, you'll get a big pretty message placeholder
in your output:

    TAG "thing" UNDEFINED

The default value is "__link__".

=item B<-[no]c>, B<--[no]cache>

The cache option enables or disables the cache. rss2text caches the date of the
latest entry it last saw, along with any HTTP caching headers it saw (ETag and 
Last-Modified values).

The default value is to cache.

=item B<--cache-dir>

This options specifies the directory in which to store cached information. This
option does nothing if caching is disabled.

The default location for the cache is under /tmp/rss2text

=head1 DESCRIPTION

rss2text takes a feed and an optional format string, grabs the feed and loops
over the returned entries, printing what was requested in the format string.
It's like printf for RSS feeds and is particularly useful for one-liners and
other places where you need a textual interface.

rss2text will, by default, try to cache as much information as possible in order to
prevent displaying entries that were seen on a previous run. This makes rss2text
especially useful for cronjobs.

=head1 DEPENDENCIES

rss2text is written in perl and uses LWP::UserAgent to grab feeds, XML::FeedPP
for parsing feeds, DateTime::Format::W3CDTF to parse dates, and Try::Tiny to
make sure DateTime::Format::W3CDTF doesn't kill the program.

Debian has packages available each:

	apt-get install libwww-perl libxml-feedpp-perl libdatetime-format-w3cdtf-perl libtry-tiny-perl

rss2text uses perl 5.10.0. Older perls can be used, but you'll have to do the
say/print-newline dance yourself.

=head1 EXAMPLES

	# print a list of new links from the feed
	./rss2text.pl http://www.schwertly.com/feed/

	# print a list of titles from the feed without using the cache
	./rss2text.pl --nocache -f "__title__" http://www.schwertly.com/feed/

	# print the title, a newline, then tab in, then the link
	./rss2text.pl -f "__title__\n\t__link__" http://www.schwertly.com/feed/

=head1 AUTHOR

Stan Schwertly (http://www.schwertly.com)

