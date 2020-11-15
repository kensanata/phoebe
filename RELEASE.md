# What to do for a release?

Run `make README.md`.

Update `Changes` with user-visible changes.

Check the copyright year in the `LICENSE`.

Increase the version in `lib/App/phoebe.pm`.

Double check the `MANIFEST`. Did we add new files that should be in
here?

Commit any changes and tag the release.

Based on [How to upload a script to
CPAN](https://www.perl.com/article/how-to-upload-a-script-to-cpan/) by
David Farrell (2016):

```
perl Makefile.PL && make && make dist
cpan-upload -u SCHROEDER App-phoebe-1.21.tar.gz
```