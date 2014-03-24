requires 'perl', '5.008001';

requires 'Class::Accessor::Lite', '0.05';
requires 'Teng',                  '0.21';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

