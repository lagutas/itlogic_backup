#!/usr/bin/perl

package itlogic_backup;
use Logic::Tools;
use DBI();

use strict;

my $path=shift;

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

################### querry for db end #########################

#if is a unit test, script does't work
if(!defined($ENV{TEST_IT}))
{
    my $backup = itlogic_backup->new();
    my $settings=$backup->get_config();

    my $tools=Logic::Tools->new(logfile => 'Syslog');
    if(!($backup->is_dir("/var/log/itlogic_backup")))
    {
        $tools->logprint("info","create dir /var/log/itlogic_backup");
        mkdir("/var/log/itlogic_backup");
    }

    my $backup = itlogic_backup->new();
    my $settings=$backup->get_config();
    my $dbh=$backup->mysql_connect($$settings{'db'},$$settings{'db_host'},$$settings{'db_user'},$$settings{'db_password'});

    $dbh->disconnect();
}

=pod


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

sub mysql_query
{
    my $self = shift;
    my $log = shift;
    my $dbh = shift;
    my $query = shift;
    my $execute_arg = shift;



    my $sth=$dbh->prepare($query);

    $log->logprint("info","try request $query");

    my $arg_string;
    eval 
    {
        #if set ref to execute_arg, args exist, serialise to string
        if(defined($execute_arg))
        {
            $arg_string=join(",",@$execute_arg);
            $sth->execute($execute_arg);    
        }
        else
        {
            $sth->execute();
        }
    };
    if ($@) 
    {
        $log->logprint("error","error in $query ($arg_string) $DBI::errstr");
    }

    my @data;
    my %string;
    while(my $ref = $sth->fetchrow_hashref())
    {   
        foreach my $key (keys %$ref)
        {
            $$log{localtime().'.'.int(rand(1000000))}="$key";
            
            push(@data,\%$ref);
            #push(@data,$string{'$key'}=$ref->{$key});
        }

        
        
    }
    $sth->finish();

    return \@data;
}

1;