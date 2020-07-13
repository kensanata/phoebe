# Start the wiki with the default options (using 'wiki' in the current
# directory as the data directory).
start:
	./gemini-wiki

# Start the wiki as a daemon with the default options, but also server
# port 443 (HTTPS); since this is a port below 1024 itis priviledges
# and requires the use of 'sudo'; the --user and --group options make
# sure that it drops priviledges to the current user as soon as it
# started.
web:
	sudo ./gemini-wiki --port=443 --port=1965 --user=$(shell id -un) --group=$(shell id -gn)

# Start the wiki on port 2020, with debug log level, two example
# spaces, allowing the upload of JPEG files, and use 'morbo' (which is
# part of the Mojolicious Perl package) to watch for changes of the
# code: when it detects a change, the server is restarted
# automatically.
dev:
	morbo -- ./gemini-wiki --port=2020 --log_level=4 --wiki_space=alex --wiki_space=berta --wiki_mime_type=image/jpeg

# Update all the documentation files
doc: README.md man

# Update the README file. The Perl script no only converts the POD
# documentation to Markdown, it also adds a table of contents.
README.md: gemini-wiki
	./update-readme

# Create man pages.
man: gemini-wiki.1 titan.1 gemini.1

%.1: %
	pod2man $< $@

# Install scripts and man pages in ~/.local
install: $$HOME/.local/bin/gemini-wiki \
	$$HOME/.local/bin/gemini \
	$$HOME/.local/bin/titan \
	$$HOME/.local/share/man/man1/gemini-wiki.1 \
	$$HOME/.local/share/man/man1/gemini.1 \
	$$HOME/.local/share/man/man1/titan.1

$$HOME/.local/bin/%: %
	cp $< $@

$$HOME/.local/share/man/man1/%: %
	cp $< $@

uninstall:
	rm \
	$$HOME/.local/bin/gemini-wiki \
	$$HOME/.local/bin/gemini \
	$$HOME/.local/bin/titan \
	$$HOME/.local/share/man/man1/gemini-wiki.1 \
	$$HOME/.local/share/man/man1/gemini.1 \
	$$HOME/.local/share/man/man1/titan.1

# Run the test using two jobs.
test:
	prove --state=slow,save --jobs 4 t/

# Run the tests individually, with the server logging debug output,
# and with the test output getting printed instead of being
# aggregated.
debug:
	for t in t/*.t; do DEBUG=4 perl "$$t"; done

# Remove all the test directories being created (use these to examine
# the situations if you run into problems).
clean:
	rm -rf test-[0-9][0-9][0-9][0-9]

# Regenerate the certificates used by the wiki. These use eliptic
# curves and are valid for five years.
cert:
	openssl req -new -x509 -newkey ec \
	-pkeyopt ec_paramgen_curve:prime256v1 \
	-days 1825 -nodes -out cert.pem -keyout key.pem

# Generate client certificates for testing. These use eliptic
# curves and are valid for five years.
client-cert:
	openssl req -new -x509 -newkey ec \
	-pkeyopt ec_paramgen_curve:prime256v1 \
	-days 1825 -nodes -out client-cert.pem -keyout client-key.pem

# Generates the fingerprint of the client certificate in a form
# suitable for comparison with fingerprints by IO::Socket::SSL.
client-fingerprint:
	openssl x509 -in client-cert.pem -noout -sha256 -fingerprint \
	| sed -e 's/://g' -e 's/SHA256 Fingerprint=/sha256$$/' | tr [:upper:] [:lower:]
