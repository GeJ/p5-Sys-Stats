requires 'perl',            '5.010001';
requires 'Capture::Tiny',   '0';
requires 'File::Slurper',   '0';
requires 'List::MoreUtils', '0';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

