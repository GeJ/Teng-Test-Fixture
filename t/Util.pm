package t::Util;
use 5.008005;
use strict;
use warnings;

use File::Spec;
use File::Basename;
use lib File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), 'lib'));

use parent 'Exporter';

use My::DB;
use My::DB::Schema;

our @EXPORT = qw(db);


my $basedir = File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__)));
my $dbpath  = File::Spec->catfile($basedir, 'data', 'test.db');
my $sqlpath = File::Spec->catfile($basedir, 'data', 'schema.sql');

sub db {
    my $schema  = My::DB::Schema->instance;
    my @conf    = ("dbi:SQLite:dbname=$dbpath", '', '', +{sqlite_unicode => 1,});
    My::DB->new(
            schema       => $schema,
            connect_info => \@conf,
        );
}

# Initialize database
{
    unlink $dbpath if -f $dbpath;
    system("sqlite3 $dbpath < $sqlpath");
}

1;
