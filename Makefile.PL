use 5.010;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'Test::Regexp',
    VERSION_FROM      => 'lib/Test/Regexp.pm',
    PREREQ_PM         => {
        Test::Builder =>  0,
        Exporter      =>  0,
    },
    AUTHOR            => 'Abigail <abigail@abigail.be>',
);
