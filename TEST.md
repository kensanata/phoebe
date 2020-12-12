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
