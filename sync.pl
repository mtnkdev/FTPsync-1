#!/usr/bin/perl

#################################################################
#																																#
#		FTP Synchronizer																						#
#		Projekt zaliczeniowy z Pracowni Jezykow Skryptowych					#
#		Uniwersytet Jagiellonski, Krakow														#
#																																#
#		Automatyczna synchronizacja zmienionego pliku na serwer			#
#		(c) 2014 Marcin Radlak																			#
#		marcin.radlak@uj.edu.pl 																		#
#		http://marcinradlak.pl 																			#
#																																#
#################################################################

use Net::FTP;
use Getopt::Std;
use strict;
use 5.010;

use vars qw($opt_s $opt_u $opt_p $opt_d $opt_h);

getopts('l:s:u:p:h');

if($opt_h || !($opt_s || $opt_u)) { usage(); }

$opt_d ||= '.';

my %remote = ();
my %local = ();

chdir $opt_d or die "Cannot change dir to $opt_d:   $!\n";

my $conn = new Net::FTP($opt_s, Passive => 1) or die "Nie udalo sie polaczyc z serwerem $opt_s.\n";
print "Polaczono z serwerem $opt_s...\n";

$conn->login($opt_u, $opt_p) or expire($conn, "Nie udalo sie zalogowac jako $opt_u.\n");
print "Zalogowano jako $opt_u...\n";

$conn->cwd("/") or expire($conn, "Blad poczatkowego katalogu.\n");
print "Poczatkowy katalog: OK...\n";

$conn->binary() or expire($conn, "Brak trybu binarnego.\n");
print "Tryb binarny: OK...\n";



traverse_local($opt_d, \%local);
traverse_remote("", \%remote);

#synchronizacja

print "Synchronizacja...\n";

my $uptodate = 1;
my $err = 0;

foreach my $file (sort { length($a) <=> length($b) } keys %local)
{
	# brak katalogu na zewnetrzym serwerze
	if($local{$file}->{type} eq "d" and !exists $remote{$file})
	{
		if(!$conn->mkdir($file))
		{
			print "+Tworze $file...\n";
			print $conn, "Nie mozna utworzyc $file...";
			$err += 1;
			next;
		}	

		$uptodate = 0;
	}

	# plik
	elsif($local{$file}->{type} eq "f" and !exists $remote{$file} and $remote{$file} < $local{$file})
	{
		print "+Przenosze $file...\n";

		if(!$conn->put($file, $file))
		{
			print "Nie mozna przesniec $file.\n";
			$err += 1;
			next;
		}

		$uptodate = 0;
	}
}

foreach my $file (sort { length($b) <=> length($a) } keys %remote)
{
  next if exists $local{$file};

  print "-Usuwam $file.\n";

  if(!$conn->delete($file))
  {
  	print "Nie mozna usunac $file.\n";
  	$err += 1;
  	next;
  }

  $uptodate = 0;
}

if($uptodate and !$err)
{
	print "Wszystkie pliki sa aktualne.\n"
}
else
{
	print "Zakonczono synchronizacje";
	print " z bledami" if $err;
	print ".\n";
}

sub traverse_local {
  my $path = shift;
	my $list = shift;
 
  return if not -d $path;
  opendir my $dh, $path or die;

  while (my $file = readdir $dh) {
    next if $file =~ m/^\.|\.\.?$/;

    my $n = (split('/', $file))[-1];

    my $name = '';
    $name = $path . '/' unless $path =~ m/^\.\.?$/;
    $name .= $file;

    my $check = $path . '/' . $file;

    my $mdtm = (stat($file))[9];
    my $size = (stat(_))[7];
    my $type = -f $check ? "f" : -d $check ? "d" : -l $file ? 'l' : '?';

    $type =~ s/-/f/;

    $list->{$name} = {
    	mdtm => $mdtm,
      size => $size,
      type => $type,
    };

    traverse_local($name, $list);
  }

  close $dh;
  return;
}

sub traverse_remote
{
	my $path = shift;
	my $list = shift;

	my $rdir = $conn->dir($path);

	return unless $rdir and @$rdir;

	for my $f (@$rdir)
  {
  	next if $f =~ m/d.+\s\.\.?$/;
  	my $n = (split(/\s+/, $f, 9))[8];
  	next if $n =~ m/^\./;

    next unless defined $n;

    my $name = '';
    $name = $path . '/' if $path;
    $name .= $n;

    next if exists $list->{$name};

    my $mdtm = ($conn->mdtm($name) || 0) + 0;
    my $size = $conn->size($name) || 0;
    my $type = substr($f, 0, 1);

    $type =~ s/-/f/;

    $list->{$name} = {
    	mdtm => $mdtm,
      size => $size,
      type => $type,
    };

    traverse_remote($name, $list) if $type eq "d";
  }
}

sub usage
{
  print "-----------------------------------------------------------------------------------------------\n";
  print " FTP Synchroniz\n\n";
  print " Uzycie: program [-s SERWER] [-u UZYTKOWNIK] [-p HASLO] [-d KATALOG] [--help|-h]\n\n";
  print " Program do automatycznej synchronizacji plikow na lokalnym serwerze ze zdalnym serwerem FTP.\n";
  print " Program porownuje pliki i foldery zawarte w katalogu podanym przez uzytkownika z zawartoscia\n";
  print " na serwerze FTP. Program rozroznia poszczegole przypadki zawartosci:\n";
  print " 1. Jesli plik znajduje sie na serwerze lokalnym, a na serwerze FTP nie, to zostanie wyslany.\n";
  print " 2. Jesli plik znajduje sie na serwerze FTP, a na serwerze lokalnym nie, to zostanie usuniety.\n";
  print " 3. Jesli plik znajduje sie na serwerze lokalnym oraz a na serwerze FTP, to zostana porownane\n";
  print " wersje. Jesli wersja pliku lokalnego okaze sie nowsza od zdalnej to plik zostanie nadpisany.\n";
  print "-----------------------------------------------------------------------------------------------\n";
  exit;
}

sub HELP_MESSAGE { usage(); }











