# TODO

- I need to rethink how with_lock works. If the code cannot execute,
  it is rescheduled, but that means we cannot close the stream. If the
  code is called via an extension, cannot execute and reschedules,
  then process_gemini closes the stream. This is not good.

- Remove %oddmuse_wiki_dirs
- colour changes ignores the current space, where as changes for all spaces does not
- add a footer
- add table processing for Wikipedia contribution back
- diff with previous version
- fix the missing client notification on SSL shutdown (according to
  gemini-diagnostics)
  https://www.openssl.org/docs/manmaster/man3/SSL_shutdown.html
  (Is this related to the memory leak when using SSL and no limits?)
