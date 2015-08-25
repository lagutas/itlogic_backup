#!/usr/bin/perl
# Скрипт создания бэкапов контейнеров OpenVZ и синхронизации их с Amazon S3
# 
# 1.0.1 - первая версия скрипта
# 1.0.2 - небольшие доработки выявленные при разветнывание на delta-ekb
# 1.1.0 - изменение структуры файлов на amazon, перенос параметров в конфигурационный файл, небольшие изменения в скрипте
# 

use strict;
use warnings;

use MIME::Lite;
use File::Basename;
use Getopt::Long;
use Log::Any;
use Log::Any::Adapter;
use Log::Log4perl qw(:easy);
Log::Any::Adapter->set('Log4perl');
use Sys::Hostname;
use Sys::Syslog;
use POSIX qw(strftime);
use Data::Dumper;
use List::Compare;
use Config::IniFiles;


my $start_date = strftime "%m-%d-%Y", localtime;
my ($path_to_log, $path_to_vzreports, $saved_day, $s3bucket, $receiver, $from, $subj);

LoadVarFromConfig("/etc/create_backup.ini");

Log::Log4perl->easy_init({	
					level  => 'INFO', 
					file   => '>>'."$path_to_log",
					layout => "%d %r ms [%P] %p: %m%n",
				});
my $log = Log::Any->get_logger();


# Функция для загрузки значений из конфигурационного файла скрипта, в случае отсуствия каких-либо значений будет подставлено дефолтное
sub LoadVarFromConfig {
 	my $path_to_config = shift;
	
	if (! -e $path_to_config) {
		print "Файл не существует\n";
		#TODO отправка на почту сообщения о том что конфигурационный файл не найден
		exit;
	}

	my $cfg = Config::IniFiles->new( -file => $path_to_config );
	
	# получаем путь до основго лога
	if ($cfg->val( 'main', 'path_to_log' )) {
	 	$path_to_log = $cfg->val( 'main', 'path_to_log' );
	}
	else {
		$path_to_log = "/var/log/create_backup.log";
	}
	# очищаем лог файл
	`echo '' > $path_to_log`;

	# получаем путь до директории с логами создания дампов
	if ($cfg->val( 'main', 'path_to_reports' )) {
	 	$path_to_vzreports = $cfg->val( 'main', 'path_to_reports' );
	 	chomp($path_to_vzreports);

	 	# смотрим не заканчивается ли путь на слэш, обрезаем
	 	if ( substr($path_to_vzreports,-1,1) eq '/' ) {
	 		chop($path_to_vzreports);	
	 	}
	 	if (! -d $path_to_vzreports) {
	 		mkdir $path_to_vzreports, 0755;
	 	}
	}
	else {
		$path_to_vzreports = "/var/log/vz_reports";
		if (! -d $path_to_vzreports) {
	 		mkdir $path_to_vzreports, 0755;
	 	}
	}

	# Получаем кол-во дней, на которое сохраняются бэкапы	
	if ($cfg->val( 'main', 'saved_day' )) {
		$saved_day = $cfg->val( 'main', 'saved_day');
		chomp($saved_day);
	}
	else {
		$saved_day = 7;
	}
	
	# Получаем бакет для сохранения
	if ($cfg->val( 'main', 'bucket_name' )) {
		$s3bucket = $cfg->val( 'main', 'bucket_name' );
		chomp($s3bucket);
	}
	else {
		my $current_hostname = `hostname`;
		chomp($current_hostname);
		$s3bucket = 's3://'.$current_hostname.'backup/';
	}

	# Получаем список email'ов для рассылки
	if ($cfg->val( 'email', 'receiver' )) {
		$receiver = $cfg->val( 'email', 'receiver' );
		chomp($receiver);

		if ($cfg->val( 'email', 'from' )) {
			$from = $cfg->val( 'email', 'from' );
			chomp($from);

			if ($cfg->val( 'email', 'subj' ) ) {
				$subj = $cfg->val( 'email', 'subj' );
				chomp($subj);
			} 
			else {
				$subj = 'Отчёт о создание бэкапов';
			} 
		}
		else {
			$from = 'messages@itlogic.pro';
		}
	}
	else {
		$receiver = '';
	}    
}

# функция генерации и отправки отчетов
sub SendReport {
	my $date = $start_date;
	$log->info("Отправка отчёта за $date");
	
	my @all_files = `ls /var/log/vz_reports/$date/`;						# получаем список всех файлов логов
	my @files_success = `grep -rlio "Backup job finished successfuly" /var/log/vz_reports/$date/`;
	my @files_success_fullpath = @files_success;

	for (my $var = 0; $var < scalar(@files_success); $var++) {
		my($file, $dir, $ext) = fileparse($files_success[$var]);
		chomp($file);
		$files_success[$var] = $file;		
	}
	for (my $var = 0; $var < scalar(@all_files); $var++) {
		chomp($all_files[$var]);
		$all_files[$var] = 	$all_files[$var];	
	}	
	
	my $lc = List::Compare->new(\@all_files, \@files_success);
	my @error_log = $lc->get_intersection;	# логи в которых имеются ошибки
	my @bad_log = $lc->get_unique;			# логи без ошибок

	# помещаем в массив адреса для отправки
	my @emails = split(',',$receiver);

	# в цикле перебираются получатили, каждому высылается отчет
	for (my $var = 0; $var < scalar(@emails); $var++) {
		# обрезаем проблемы
		$emails[$var] =~ s/^\s+|\s+$//g;

		#print "Send to $emails[$var] \n";

		my $msg = MIME::Lite->new(
        	Subject => $subj,
        	To      => "$emails[$var]",
       		From	=> $from,
        	Type    =>'multipart/mixed'
    	);

		my $bad_html = "<p>Неуспешно:</p>";
    	for (my $var = 0; $var < scalar(@bad_log); $var++) {
    		$bad_html = $bad_html . "<li>" . $bad_log[$var] . "</li>";
    	}
    	my $failed_html = "<p>Успешно:</p>";
		for (my $var = 0; $var < scalar(@error_log); $var++) {
    		$failed_html = $failed_html . "<li>" . $error_log[$var] . "</li>";
    	}

	    $msg->attach(
    	    Type => 'text/html',
        	Data => qq{
            	<body>
                	$bad_html
                	$failed_html
            	</body>
        	},
    	);
    
    	for (my $var = 0; $var < scalar(@bad_log); $var++) {
    		chomp($bad_log[$var]);
    		$msg->attach(
        		Type => 'text/plain',        	
        		Path => "$path_to_vzreports/$date/$bad_log[$var]",
        		Filename => "$path_to_vzreports/$date/$bad_log[$var]",
    	    	Disposition => 'attachment'
    		);			
    	}
    	for (my $var = 0; $var < scalar(@files_success_fullpath); $var++) {
    		chomp($files_success_fullpath[$var]);
    		$msg->attach(
	        	Type => 'text/plain',        	
    	    	Path => "$files_success_fullpath[$var]",
    	    	Filename => "$files_success_fullpath[$var]",
    	    	Disposition => 'attachment'
    		);	
    	}

    	# отправляем лог бэкапов общий
    	$msg->attach(
	        	Type => 'text/plain',        	
    	    	Path => "$path_to_log",
    	    	Filename => "$path_to_log",
    	    	Disposition => 'attachment'
    		);	
    	$msg->send();
	}
}

# функция создания бэкапа контенйре с помощью vzdump
sub BackupContainer {
	my $ctid = shift;	
	
	unless ($ctid) {
	 	$log->error("Не передан ctid!");
	 	exit 1;
	}
	
	my $date = strftime "%m-%d-%Y", localtime;
	
	my $dirname ="$path_to_vzreports/$date/";
	mkdir $dirname, 0755;
	
	# Получаем список контейнеров openvz
	my $vzresult = `vzlist -a | awk '{ print \$1; }' | grep $ctid | wc -l`;
	
	if ($vzresult != 0) {			
		$log->info("Контейнер $ctid существует, делаем бэкап");
		mkdir '/vz/dump/'.$start_date, 0755;
		`vzdump --suspend --compress $ctid --dumpdir /vz/dump/$start_date --exclude-path "/var/spool/asterisk/monitor/.*"> $dirname/$ctid.log`;
	} else {
		$log->error("Контейнер $ctid не существует");
		exit 1;
	}
}

# функция очистки дампов
sub ClearDir {
	$log->info("Удаление файлов старше $saved_day дня.");
	`find $path_to_vzreports -mtime +"$saved_day" -delete`;
	`find /vz/dump/ -mtime +"$saved_day" -delete`;
	if ($? != 0) {
		$log->error("Произошла ошибка при удаление файлов");
	}
	else {
		$log->info("Удаление файлов старше $saved_day дней прошло успешно");
	}
}

sub SyncWithS3 {
	my $result=`s3cmd --acl-private --bucket-location=EU --guess-mime-type --delete-removed sync /vz/dump/ $s3bucket`;
        if($? != 0) {
            $log->error("Возникли ошибки при синхронизации с amazon");
        }
        else {
            $log->info("Синхронизация с amazon успешно завершена");
        }
}

sub Main {
	my $ctid = 0;
	my $action = "backup";	# defaul action
	my $result = GetOptions("action=s" => \$action, "ctid=i" => \$ctid);

	ClearDir();
	
	if ($action eq "backup") {
		if ($ctid == 0) {
			$log->info("Делаем бэкап всех контейнеров");
			my @ctid_array = `vzlist -a | awk '{ print \$1; }' | grep "[0-9].*"`;
			
			for (@ctid_array) {
				chomp($_);
				BackupContainer($_);
			}
			# --no-progress
			my $result=`s3cmd --acl-private --bucket-location=EU --guess-mime-type --delete-removed sync /vz/dump/ $s3bucket`;
			if($? != 0) {
				$log->error("Возникли ошибки при синхронизации с amazon");
			}
			else {
				$log->info("Синхронизация с amazon успешно завершена");
			}
		} else {
			$log->info("Делаем бэкап контейнера $ctid");
			BackupContainer($ctid);
			my $result=`s3cmd --acl-private --no-progress --bucket-location=EU --guess-mime-type --delete-removed sync /vz/dump/ $s3bucket`;
			if($? != 0) {
				$log->error("Возникли ошибки при синхронизации с amazon");
			}
			else {
				$log->info("Синхронизация с amazon успешно завершена");
			}
		}
		SendReport();
	}
	elsif ($action eq "clear") {
		ClearDir();
	}
	else {
		$log->error("Неверно переданные параметр $action");
		exit 1;
	}
}

Main();
#SyncWithS3();
