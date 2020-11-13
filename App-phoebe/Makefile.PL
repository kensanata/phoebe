use 5.008004;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME             => 'App::phoebe',
  VERSION_FROM     => 'lib/App/phoebe.pm',
  ABSTRACT_FROM    => 'lib/App/phoebe.pm',
  AUTHOR           => 'Alex Schroeder',
  LICENSE          => 'agpl_3',
  MIN_PERL_VERSION => '5.26.0', # Modern::Perl '2018'
  EXE_FILES        => [
    'script/phoebe',
    'script/phoebe-ctl',
    'script/gemini',
    'script/titan',
  ],
  PREREQ_PM        => {
    'strict'   => 0,
    'warnings' => 0,
    'Algorithm::Diff' => 0,
    'File::ReadBackwards' => 0,
    'IO::Socket::INET6' => 0,
    'IO::Socket::SSL' => 0,
    'Modern::Perl' => 0,
    'Net::Server' => 0,
    'URI::Escape' => 0,
  },
  META_MERGE => {
    'meta-spec' => { version => 2 },
    resources => {
      repository => {
	type => 'git',
	url  => 'https://alexschroeder.ch/cgit/phoebe',
	web  => 'https://alexschroeder.ch/cgit/phoebe/about/',
      },
    },
  },
  clean => {
    FILES => "test-[0-9][0-9][0-9][0-9]",
  },
);
