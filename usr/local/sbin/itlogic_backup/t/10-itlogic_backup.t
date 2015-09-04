use strict;

my $path=shift;

use Test::More tests => 7;

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
                                    $test_dir=~s/^(.+\/\d+.+sbin)\/.+$/$1/;
                                    $test_dir=$test_dir."/itlogic_backup/t/test_dir";
                                    is($backup->is_dir($test_dir),'0','if is dir not exist - ok');

                                    mkdir($test_dir);
                                    is($backup->is_dir($test_dir),'1','if is dir exist - ok');
                                };

#7
subtest 'mysql is work' => sub  {
                                    $ENV{DEPLOY_PATH} = $deploy_path;
                                    my $fork_path=$path;
                                    $fork_path=~s/^(.+\/\d+.+project)\/.+$/$1/;
                                    $fork_path=$fork_path."/fork_proc/script/";

                                    my $logfile=$path;
                                    $logfile=~s/^(.+\/\d+.+project)\/.+$/$1/;
                                    $logfile=$logfile."/fail2ban/t/";

                                    my $fail2ban = Fail2ban->new(fork_path  => $fork_path,
                                                                 logfile    => $logfile."mysql_test.log");
                                    my $settings=$fail2ban->get_config();
                                    my $dbh=$fail2ban->mysql_connect($$settings{'db'},$$settings{'db_host'},$$settings{'db_user'},$$settings{'db_password'});

                                    my %log;
                                    tie(%log,'IPC::Shareable','log',{   create     => 'yes',
                                                                        destroy    => 'yes',
                                                                        exclusive  => 0,
                                                                        mode       => '0644'}) or die "Can't tie \%log to shared memory: $!";
                                    like( $dbh, qr/^DBI\:\:db=HASH.+/, 'mysql_connect ok - return hash' );

                                    my $data1=$fail2ban->mysql_query(\%log,$dbh,"select 'this is a test' as arg;");
                                    
                                    foreach(@$data1)
                                    {
                                        is ($_->{'arg'}, 'this is a test', "mysql_query with 1 arg is ok");
                                    }

                                    my $data2=$fail2ban->mysql_query(\%log,$dbh,"select 'this is a test 1' as arg1, 'this is a test 2' as arg2;");
                                    
                                    foreach(@$data2)
                                    {
                                        is ($_->{'arg1'}, 'this is a test 1', "mysql_query with 2 arg is ok");
                                        is ($_->{'arg2'}, 'this is a test 2', "mysql_query with 2 arg is ok");
                                    }

                                    my $data3=$fail2ban->mysql_query(\%log,$dbh,"select ? as arg","this is a test");

                                    foreach(@$data3)
                                    {
                                        is ($_->{'arg'}, 'this is a test', "mysql_query with 1 bind is ok");
                                    }

                                    my $data4=$fail2ban->mysql_query(\%log,$dbh,"select ? as arg1, ? as arg2","this is a test 1,this is a test 2");

                                    foreach(@$data4)
                                    {
                                        is ($_->{'arg1'}, 'this is a test 1', "mysql_query with 2 bind is ok");
                                        is ($_->{'arg2'}, 'this is a test 2', "mysql_query with 2 bind is ok");
                                    }

                                    my $data5=$fail2ban->mysql_query(\%log,$dbh,"select ? as arg1, ? as arg2, ? as arg3","this is a test 1,this is a test 2,this is a test 3");

                                    foreach(@$data5)
                                    {
                                        is ($_->{'arg1'}, 'this is a test 1', "mysql_query with 3 bind is ok");
                                        is ($_->{'arg2'}, 'this is a test 2', "mysql_query with 3 bind is ok");
                                        is ($_->{'arg3'}, 'this is a test 3', "mysql_query with 3 bind is ok");
                                    }

                                    $dbh->disconnect();

                                    my $result = ae_recv{
                                                            $fail2ban->run_logger(ae_send);
                                                        } 
                                                        soft_timeout => 2;
                                    (tied %log)->remove;
                                };