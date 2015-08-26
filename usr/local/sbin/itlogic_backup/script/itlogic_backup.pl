#!/usr/bin/perl

package itlogic_backup;
use Logic::Tools;
use DBI();

use strict;

my $path=shift;


#if is a unit test, script does't work
if(!defined($ENV{TEST_IT}))
{
    my $backup = itlogic_backup->new();
    my $settings=$backup->get_config();
}

=pod
if(!is_dir("/var/log/itlogic_backup"))
{
    mkdir("/var/log/itlogic_backup");
}

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

=cut



sub new
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;

    my $self = { @_ };
    bless $self, $class;
    
    return $self;
}


sub get_config
{
    my $self = shift;

    my $logfile = $self->{'logfile'} || 'Syslog';

    my $tools=Logic::Tools->new(config_file =>  $ENV{DEPLOY_PATH}.'/etc/itlogic_backup/backup.ini',
                                logfile     =>  $logfile);

    my %settings;
    $settings{'db_host'}=$tools->read_config( 'main', 'db_host');
    $settings{'db'}=$tools->read_config( 'main', 'db');
    $settings{'db_user'}=$tools->read_config( 'main', 'db_user');
    $settings{'db_password'}=$tools->read_config( 'main', 'db_password');
    $settings{'db_password1'}=$tools->read_config( 'main', 'db_password1');

    return \%settings;
}


sub is_dir
{
    my $self = shift;

    my $dir = shift;

    if ( -d $dir ) 
    {
        return 1;
    } 
    else 
    { 
        return 0; 
    }
}

sub mysql_connect
{
    my $self = shift;

    my $db = shift;
    my $db_host = shift;
    my $db_user = shift;
    my $db_password = shift;

    my $dbh;
    eval 
    {
        $dbh=DBI->connect("DBI:mysql:$db;host=$db_host",$db_user,$db_password);
    };
    if ($@) 
    {
        die "Error: не удается подключиться к базе данных $db $db_host $db_user $DBI::errstr\n"
    }
    $dbh->{mysql_auto_reconnect} = 1;

    return $dbh;
}

1;