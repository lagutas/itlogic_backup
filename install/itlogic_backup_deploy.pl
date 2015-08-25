#!/usr/bin/perl

use Cwd;
use Logic::Tools;
use Text::Diff;
use strict;

my $path=shift;
my $emails=shift;

my $my_dir = getcwd;
my $tools=Logic::Tools->new(logfile         =>      $my_dir.'/'.$path.'/deploy.log');


my $command='sudo '.$path.'/install/test_install_script.pl'.
                            ' -path '.$path.
                            ' -script_name itlogic_backup.pl'.
                            ' -src_script_dir '.$path.'/usr/local/sbin/itlogic_backup'.
                            ' -dst_script_dir /usr/local/sbin'.
                            ' -script_cfg_name backup.ini'.
                            ' -src_script_cfg_dir '.$path.'/etc/itlogic_backup'.
                            ' -dst_script_cfg_dir /etc/itlogic_backup'.
                            ' -test_dir '.$path.'/usr/local/sbin/itlogic_backup/t'.
                            ' -emails '.$emails;
$tools->logprint("info","exec $command");
my $test_result=`$command`; 
$tools->logprint("info","exec test_result $test_result");
if($test_result<0) 
{
    $tools->logprint("error","unit test return errors");
    exit;
}
elsif($test_result>0)
{
    $tools->logprint("info","unit test return command to restart script");
}
else
{
    $tools->logprint("info","unit test return command not need restart script");    
}