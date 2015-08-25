#!/usr/bin/perl

use strict;
use warnings;
use Logic::Tools;
use DBI();


my $path=shift;


if(!is_dir("/var/log/itlogic_backup"))
{
    mkdir("/var/log/itlogic_backup");
}

my ($sec, $min, $hour, $day, $mon, $year) = ( localtime(time) )[0,1,2,3,4,5];

my $logfile=sprintf("%s_%04d_%02d_%02d_%02d_%02d%s",'/var/log/itlogic_backup/backup_',$year+1900,$mon+1,$day,$hour,$min,'.log');

my $tools=Logic::Tools->new(logfile         =>      $logfile,
                            config_file     =>      '/etc/itlogic_backup/backup.ini');

my $db_host=$tools->read_config( 'main', 'db_host');
my $db=$tools->read_config( 'main', 'db');
my $db_user=$tools->read_config( 'main', 'db_user');
my $db_password=$tools->read_config( 'main', 'db_password');

################### querry for db ##############################
my %query;
$query{'get_backup_tasks'} = <<EOQ;
SELECT
    cdor.ctid,IFNULL(cs.`month`,0) as month, IFNULL(cs.`day`,0) as day, IFNULL(cdor.exlude_dir,0) as exlude_dir
FROM
    ctid_dump_options_rules cdor
    JOIN ctid_schedule cs ON cdor.id = cs.ctid_dump_options_rules_id
    JOIN servers s ON s.id = cdor.servers_id
WHERE
    s.domain='planetahost'
    order by cdor.priority;
EOQ

$query{'check_user_exist'} = <<EOQ;
SELECT
    count(*) as num
FROM
    $db.access_matrix am
    JOIN $db.servers s ON s.id = am.servers_id
    JOIN $db.users u ON u.id = am.users_id
    JOIN $db.sudo_rules sr ON sr.id = am.sudo_rules_id
WHERE
    s.domain = ? AND
    u.login =?;
EOQ

$tools->logprint("info","start_backup");

my $dbh;
eval 
{
    $dbh=DBI->connect("DBI:mysql:$db;host=$db_host",$db_user,$db_password) or die "Error: can't connect to $db $db_host $db_user: $!\n";
};
if ($@) 
{
    die "Error: can't connect to $db $db_host $db_user $!\n";
}
$dbh->{mysql_auto_reconnect} = 1;







$dbh->disconnect();
sub is_dir
{
    if ( -d $_[0] ) 
    {
        return 1;
    } 
    else 
    { 
        return 0; 
    }
}
