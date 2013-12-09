# rss2text

Takes a feed and optional format string, and prints for every new entry.

# USAGE

	./rss2text.pl URL
	./rss2text.pl URL "__title__: __link__"

# DESCRIPTION

rss2text takes a feed and an optional format string, grabs the feed and loops
over the returned entries, printing what was requested in the format string.
It's like printf for RSS feeds and is particularly useful for one-liners and
other places where you need a textual interface.

rss2text assumes a default format string of "\_\_link\_\_", which will loop over
entries and print the URL for each entry.

By default, rss2text caches hits to the URL under /tmp/rss2text. If a
cached file is available, it will read it and only loop over entries that are
newer than the last time it ran. This makes rss2text especially useful for cronjobs.
Specifically, rss2text stores the date of the last entry it saw, along with the
ETag and Last-Modified header (if seen).

The format string can take any child elements that belong in an entry. Typical
entries include "title", "description", "published", "link", and "author". The
format string allows you to identify these elements by wrapping them in double
underscores. Printing the title of every link is achieved by passing in the
format string as "\_\_title\_\_". If you want to print the title, a colon and a single
space, and then the link, simply pass "\_\_title\_\_: \_\_link\_\_".

You can request anything you'd like if you know that a feed will have the item
you're requesting. If it's not there, you'll get a big pretty message placeholder
in your output:

	TAG "thing" UNDEFINED

Check your placeholders!

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

	# print the title, a newline, then tab in, then the link
	./rss2text.pl http://www.schwertly.com/feed/ "__title__\n\t__link__"

# AUTHOR

Stan Schwertly (http://www.schwertly.com)
