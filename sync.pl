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

getopts('s:u:p:d:h');

if($opt_h || !($opt_s || $opt_u)) { usage(); }

$opt_d ||= '.';

my $self = $0;
$self =~ s/.\///g;

my %remote = ();
my %local = ();

chdir $opt_d or die "Nie mozna otworzyc sciezki $opt_d.\n";

my $conn = new Net::FTP($opt_s, Passive => 1) or die "Nie udalo sie polaczyc z serwerem $opt_s.\n";
print "Polaczono z serwerem $opt_s...\n";

$conn->login($opt_u, $opt_p) or die "Nie udalo sie zalogowac jako $opt_u.\n";
print "Zalogowano jako $opt_u...\n";

$conn->cwd("/") or die $conn, "Blad poczatkowego katalogu.\n";
print "Poczatkowy katalog: OK...\n";

$conn->binary() or die $conn, "Brak trybu binarnego.\n";
print "Tryb binarny: OK...\n";

traverse_local(".", \%local);
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
	elsif($local{$file}->{type} eq "f" and (!exists $remote{$file} or $remote{$file}{size} != $local{$file}{size}))
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
    if(!$conn->rmdir($file))
    {
  	  print "Nie mozna usunac $file.\n";
  	  $err += 1;
  	  next;
    }
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
    next if $file eq $self;

    my $ready = '';
    $ready = $path . '/' unless $path =~ m/^\.\.?$/;
    $ready .= $file;

    my $check = $path . '/' . $file;
    my $type = -f $check ? "f" : -d $check ? "d" : -l $file ? 'l' : '?';
    $type =~ s/-/f/;

    my $size = (stat(_))[7];
    my $mdtm = (stat($file))[9];

    $list->{$ready} = {
      type => $type,
      size => $size,
    	mdtm => $mdtm,
    };

    traverse_local($ready, $list);
  }

  close $dh;
  return;
}

sub traverse_remote
{
	my $path = shift;
	my $list = shift;

	my $dh = $conn->dir($path);
	return unless $dh and @$dh;

	for my $file (@$dh)
  {
  	next if $file =~ m/d.+\s\.\.?$/;
  	my $nc = (split(/\s+/, $file, 9))[8];
  	next if $nc =~ m/^\./;

    next unless defined $nc;

    my $ready = '';
    $ready = $path . '/' if $path;
    $ready .= $nc;

    next if exists $list->{$ready};

    my $type = substr($file, 0, 1);
    $type =~ s/-/f/;

    my $size = $conn->size($ready) || 0;
    my $mdtm = ($conn->mdtm($ready) || 0) + 0;   

    $list->{$ready} = {
      type => $type,
      size => $size,
      mdtm => $mdtm,
    };

    traverse_remote($ready, $list) if $type eq "d";
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

