# What to do for a release?

Run `make README.md`.

Update `Changes` with user-visible changes.

Check the copyright year in the `LICENSE`.

Double check the `MANIFEST`. Did we add new files that should be in
here?

```
make manifest
```

Increase the version in `lib/App/Phoebe.pm`.

Commit any changes and tag the release.

Prepare an upload by using n.nn_nn for a developer release:

```
make distdir
mv App-phoebe-4 App-phoebe-4.00_00
tar czf App-phoebe-4.00_00.tar.gz App-phoebe-4.00_00
trash App-phoebe-4.00_00
cpan-upload -u SCHROEDER App-phoebe-4.00_00.tar.gz
```

If you’re happy with the results:

```
perl Makefile.PL && make && make dist
cpan-upload -u SCHROEDER App-phoebe-4.tar.gz
```
