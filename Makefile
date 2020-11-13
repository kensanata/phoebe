# Start the wiki with the default options (using 'wiki' in the current
# directory as the data directory). This also uses unsafe certificates
# from the test directory. Don't use them in production. See the cert
# target to make your own. :)
start:
	./App-phoebe/script/phoebe \
	  --cert_file=./App-phoebe/t/cert.pem \
	  --key_file=./App-phoebe/t/key.pem

# Start the wiki as a daemon with the default options, but also server
# port 443 (HTTPS). As this is a port below 1024 it is priviledged and
# requires the use of 'sudo'; the --user and --group options make sure
# that it drops priviledges to the current user as soon as it started.
web:
	sudo ./App-phoebe/script/phoebe \
	  --cert_file=./App-phoebe/t/cert.pem \
	  --key_file=./App-phoebe/t/key.pem \
          --user=$(shell id -un) --group=$(shell id -gn) \
          --port=443 --port=1965

# Start the wiki on port 2020, with debug log level, two example
# spaces, allowing the upload of JPEG files, and use 'morbo' (which is
# part of the Mojolicious Perl package) to watch for changes of the
# code: when it detects a change, the server is restarted
# automatically.
dev:
	morbo --watch ./App-phoebe/script/phoebe \
	      --watch ./wiki/config -- \
	  ./App-phoebe/script/phoebe \
	    --host localhost --host 127.0.0.1 --port=2020 \
	    --wiki_space=127.0.0.1/alex --wiki_space=localhost/berta \
	    --log_level=4 --wiki_main_page=Welcome \
	    --wiki_mime_type=image/jpeg

# Update the README file. The Perl script no only converts the POD
# documentation to Markdown, it also adds a table of contents.
README.md: App-phoebe/script/phoebe
	./update-readme App-phoebe/script/phoebe

# Run the test using multiple jobs.
test:
	cd App-phoebe && prove --state=slow,save --jobs 4 t/

# Run the tests individually, with the server logging debug output,
# and with the test output getting printed instead of being
# aggregated.
debug:
	cd App-phoebe && for t in t/*.t; do DEBUG=4 perl "$$t"; done

# Regenerate the certificates used by the wiki. These use eliptic
# curves and are valid for five years.
cert:
	openssl req -new -x509 -newkey ec \
	-pkeyopt ec_paramgen_curve:prime256v1 \
	-days 1825 -nodes -out cert.pem -keyout key.pem

# Print all the info about the certificate.
cert-info:
	openssl x509 -in cert.pem -text

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

# How to generate a distribution, based on
# https://www.perl.com/article/how-to-upload-a-script-to-cpan/
dist:
	cd App::phoebe && perl Makefile.PL && make manifest && make && make dist
	echo "Now run cpan-upload -u SCHROEDER App-phoebe/App-phoebe-1.1.tar.gz"
