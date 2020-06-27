start:
	./gemini-wiki.pl

README.md: gemini-wiki.pl
	rm -f README.md && pod2readme --format markdown $<

test:
	prove t

clean:
	rm -rf test-[0-9][0-9][0-9][0-9]

cert:
	openssl req -new -x509 -nodes -out cert.pem -keyout key.pem
