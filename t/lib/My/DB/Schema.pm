package My::DB::Schema;
use strict;
use warnings;
use utf8;
use DBI qw(:sql_types);
use Teng::Schema::Declare;

table {
    name 'division';
    pk 'id';
    columns 
        { name => 'id',          type => SQL_INTEGER, },
        { name => 'name',        type => SQL_VARCHAR, },
    ;
};

table {
    name 'project';
    pk 'id';
    columns
        { name => 'id',          type => SQL_INTEGER, },
        { name => 'name',        type => SQL_VARCHAR, },
        { name => 'division_id', type => SQL_INTEGER, },
    ;
};

table {
    name 'employee';
    pk 'id';
    columns 
        { name => 'id',          type => SQL_INTEGER, },
        { name => 'name',        type => SQL_VARCHAR, },
        { name => 'division_id', type => SQL_INTEGER, },
    ;
};

table {
    name 'team';
    pk 'id';
    columns
        { name => 'id',          type => SQL_INTEGER, },
        { name => 'name',        type => SQL_VARCHAR, },
        { name => 'division_id', type => SQL_INTEGER, },
        { name => 'project_id',  type => SQL_INTEGER, },
    ;
};

table {
    name 'team_members';
    pk qw(employee_id division_id team_id);
    columns
        { name => 'employee_id', type => SQL_INTEGER, },
        { name => 'division_id', type => SQL_INTEGER, },
        { name => 'team_id',     type => SQL_INTEGER, },
    ;
};

1;
