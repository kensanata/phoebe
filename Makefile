start:
	./gemini-wiki.pl

test:
	prove t

clean:
	rm -rf test-[0-9][0-9][0-9][0-9]

cert:
	openssl req -new -x509 -nodes -out cert.pem -keyout key.pem
