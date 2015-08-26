use strict;
use warnings;

my $path=shift;

use Test::More tests => 6;

use_ok( 'Logic::Tools');                                                                                    #1
use_ok( 'DBI');                                                                                             #2


#3
my $deploy_path=$path;
$deploy_path=~s/^(.+\/\d+)\/.+$/$1/;
$ENV{DEPLOY_PATH} = $deploy_path;
$ENV{TEST_IT}=1;
require_ok($path.'/itlogic_backup.pl');

#4
subtest 'creates correct object' => sub {
                                            isa_ok(itlogic_backup->new, 'itlogic_backup');
                                        };

#5
subtest 'correct config' => sub {
                                    $ENV{DEPLOY_PATH} = $deploy_path;
                                    my $backup = itlogic_backup->new();
                                    my $settings=$backup->get_config();
                                    like( $settings, qr/^HASH.+/, 'hash settings ok' );
                                };

#6
subtest 'is_dir work fine' => sub {
                                    $ENV{DEPLOY_PATH} = $deploy_path;
                                    my $backup = itlogic_backup->new();

                                    my $test_dir=$path;
                                    $test_dir=~s/^(.+\/\d+.+project)\/.+$/$1/;
                                    $test_dir=$test_dir."/itlogic_backup/t/test_dir";
                                    is($backup->is_dir($test_dir),'0','if is dir not exist - ok');

                                    mkdir($test_dir."/itlogic_backup/t/test_dir");
                                    is($backup->is_dir($test_dir),'1','if is dir exist - ok');
                                };