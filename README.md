# rss2text

Takes a feed and optional format string, and prints for every new entry.

# USAGE

	./rss2text.pl URL
	./rss2text.pl --format "__title__: __link__" URL

# SYNOPSIS

	./rss2text [options] URL

	Options:
	  -f, --format          template string for returning results.
	  -[no]c, --[no]cache   enables/disables cache.
	  --cache_dir           location of the cache directory.
	  --cookie_path         path to a cookie to send with the request

# OPTIONS

- __\-f__ _format string_, __\--format__=_format string_

The format string dictates how rss2text returns your data. It can include any
static text you'd like along with placeholders, which use double underscores
to separate themselves. A placeholder looks like \_\_name\_\_ and will be substituted
with the child element of the feed entry. 

The format string can take any child elements that belong in an entry. Typical
placeholders include "title", "description", "published", "link", and "author".
Printing the title of every link is achieved by passing in the format string as
"\_\_title\_\_". If you want to print the title, a colon and a single
space, and then the link, simply pass "\_\_title\_\_: \_\_link\_\_".

You can request anything you'd like if you know that a feed will have the item
you're requesting. If it's not there, you'll get a big pretty message placeholder
in your output:

    TAG "thing" UNDEFINED

The default value is "\_\_link\_\_".

- __\-\[no\]c__, __\--\[no\]cache__

The cache option enables or disables the cache. rss2text caches the date of the
latest entry it last saw, along with any HTTP caching headers it saw (ETag and 
Last-Modified values).

The default value is to cache.

- __\--cache\_dir__

This option specifies the directory in which to store cached information. This
option does nothing if caching is disabled.

The default location for the cache is under /tmp/rss2text

- __\--cookie\_path__

Specifies the location of a cookie to be sent along with the request. The cookie
must be saved in Netscape format (or more usefully: the format that "curl"
saves cookies in.)

rss2text by default does not send any cookie along with requests.

# DESCRIPTION

rss2text takes a feed and an optional format string, grabs the feed and loops
over the returned entries, printing what was requested in the format string.
It's like printf for RSS feeds and is particularly useful for one-liners and
other places where you need a textual interface.

rss2text will, by default, try to cache as much information as possible in order to
prevent displaying entries that were seen on a previous run. This makes rss2text
especially useful for cronjobs.

# DEPENDENCIES

rss2text is written in perl and uses LWP::UserAgent to grab feeds, XML::FeedPP
for parsing feeds, DateTime::Format::W3CDTF to parse dates, and Try::Tiny to
make sure DateTime::Format::W3CDTF doesn't kill the program.

Debian has packages available for each:

	apt-get install libwww-perl libxml-feedpp-perl libdatetime-format-w3cdtf-perl libtry-tiny-perl libhttp-cookies-perl

rss2text uses perl 5.10.0. Older perls can be used, but you'll have to do the
say/print-newline dance yourself.

# EXAMPLES

	# print a list of new links from the feed
	./rss2text.pl http://www.schwertly.com/feed/

	# print a list of titles from the feed without using the cache
	./rss2text.pl --nocache -f "__title__" http://www.schwertly.com/feed/

	# print the title, a newline, then tab in, then the link
	./rss2text.pl -f "__title__\n\t__link__" http://www.schwertly.com/feed/

# AUTHOR

Stan Schwertly (http://www.schwertly.com)
