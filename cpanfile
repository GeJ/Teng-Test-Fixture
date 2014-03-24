requires 'perl', '5.008005';

requires 'DBD::SQLite',           '0';
requires 'Class::Accessor::Lite', '0.05';
requires 'File::Spec',            '0';
requires 'Teng',                  '0.21';
requires 'Scalar::Util',          '0';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Deep';
};

