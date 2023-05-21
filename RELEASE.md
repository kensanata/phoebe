# What to do for a release?

Run `make README.md`.

Update `Changes` with user-visible changes.

Check the copyright year in the `LICENSE`.

Double check the `MANIFEST`. Did we add new files that should be in
here?

```
perl Makefile.PL
make manifest
```

Increase the version in `lib/App/Phoebe.pm`.

Commit any changes and tag the release.

Prepare an upload by using n.nn_nn for a developer release:

```
perl Makefile.PL
make distdir
mv App-Phoebe-4.07 App-Phoebe-4.07_01
tar czf App-Phoebe-4.07_01.tar.gz App-Phoebe-4.07_01
trash App-Phoebe-4.07_01
cpan-upload -u SCHROEDER App-Phoebe-4.07_01.tar.gz
```

If you’re happy with the results:

```
perl Makefile.PL && make && make dist
cpan-upload -u SCHROEDER App-Phoebe-4.07.tar.gz
```
