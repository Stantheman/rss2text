# rss2text

Takes a feed and optional format string, and prints for every new entry.

# USAGE

		./rss2text.pl URL
		./rss2text.pl URL "__title__: __link__"

# DESCRIPTION

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
entries include:

 * title
 * description
 * published
 * link
 * author

You can request anything you'd like if you know that a feed will have the item
you're requesting.

# DEPENDENCIES

rss2text is written in perl and uses LWP::UserAgent to grab feeds, XML::FeedPP
for parsing feeds, and DateTime::Format::W3CDTF to parse dates.

Debian has packages available each:

		apt-get install libwww-perl libxml-feedpp-perl libdatetime-format-w3cdtf-perl

rss2text uses perl 5.10.0. Older perls can be used, but you'll have to do the
say/print-newline dance yourself.

# EXAMPLES

		# print a list of new links from the feed
		./rss2text.pl http://www.schwertly.com/feed/

		# print a list of titles from the feed
		./rss2text.pl http://www.schwertly.com/feed/ "__title__"

# AUTHOR

Stan Schwertly (http://www.schwertly.com)


