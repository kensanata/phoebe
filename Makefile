start:
	./gemini-wiki.pl

web:
	sudo ./gemini-wiki.pl --port=443 --port=1965 --user=$(shell id -un) --group=$(shell id -gn)

dev:
	morbo -- ./gemini-wiki.pl --port=2020 --log_level=4 --wiki_space=alex --wiki_space=berta

README.md: gemini-wiki.pl
	./update-readme.pl

test:
	prove --jobs 2 t

clean:
	rm -rf test-[0-9][0-9][0-9][0-9]

cert:
	openssl req -new -x509 -nodes -out cert.pem -keyout key.pem
