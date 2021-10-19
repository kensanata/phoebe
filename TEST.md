# Testing

Regular testing if everything is working:

```
perl Makefile.PL && make test
```

In order to run the basic tests, possibly setting `--log_level=debug`
in `t/test.pl`

```
perl Makefile.PL && make test TEST_VERBOSE=1 TEST_FILES=t/basics.t 
```

To run all the tests:

```
AUTHOR_TEST=1 make test
```

To make absolutely sure you have no missing dependencies, use Docker:

```
docker run --interactive --tty --publish=1965:1965 --volume=$(pwd):/phoebe perl:latest bash
cd phoebe
perl Makefile.PL && cpanm .
```

Please note that the next time you run docker, all the CPAN
installations you are gone. Don’t run this command too often.
And if you do, don’t leave early.
