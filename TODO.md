# TODO

- Remove %oddmuse_wiki_dirs
- colour changes ignores the current space, where as changes for all spaces does not
- add a footer
- add table processing for Wikipedia contribution back
- diff with previous version
- fix the missing client notification on SSL shutdown (according to
  gemini-diagnostics)
  https://www.openssl.org/docs/manmaster/man3/SSL_shutdown.html
  (Is this related to the memory leak when using SSL and no limits?)

Sometimes I still see multiple DNS TXT queries for the same number
within seconds of each other. Why isn’t this cached somewhere?
