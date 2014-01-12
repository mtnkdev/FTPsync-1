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

use strict;
use Net::FTP;
use File::Find;
use Pod::Usage;
use Getopt::Std;
use Getopt::Long;

use vars qw($opt_s $opt_k $opt_u $opt_l $opt_p $opt_r $opt_h $opt_d $opt_P $opt_i $opt_o);

getopts('i:o:l:s:u:p:r:hkvdP');

sub usage
{
  print "-----------------------------------------------------------------------\n";
  print " FTP Synchroniz\n\n";
  print " Uzycie: program [-s SERWER] [-u UZYTKOWNIK] [-p HASLO] [--help|-h]\n\n";
  print " Program do automatycznej synchronizacji plikow na lokalnym serwerze ze zdalnym serwerem FTP.\n";
  print "-----------------------------------------------------------------------\n";
  exit;
}

sub HELP_MESSAGE { usage(); }

if($opt_h || !($opt_s || $opt_u)) { usage(); }

$opt_s ||= 'localhost';
$opt_u ||= 'anonymous';
$opt_p ||= 'someuser@';
$opt_r ||= '/';
$opt_l ||= '.';
$opt_o ||= 0;
$opt_i = qr/$opt_i/ if $opt_i;

my %remote = ();
my %local = ();

chdir $opt_l or die "Cannot change dir to $opt_l:   $!\n";

find({
	no_chdir       => 1,
  follow         => 0,
  wanted         => sub {

    return if $File::Find::name eq '.';

    $File::Find::name =~ s!^\./!!;

    if($opt_i and $File::Find::name =~ m/$opt_i/)
    {
      print "local: IGNORING $File::Find::name\n";
      return;
    }

    my $r = $local{$File::Find::name} = {
      mdtm => (stat($File::Find::name))[9],
      size => (stat(_))[7],
      type => -f _ ? 'file' : -d _ ? 'directory' : -l $File::Find::name ? 'l' : '?',
    };

    print "local: adding $File::Find::name (", "$r->{mdtm}, $r->{size}, $r->{type})\n" if $opt_d;

  },
}, '.' );

my $conn = new Net::FTP($opt_s, Passive => 1) or die "Nie udalo sie polaczyc z serwerem $opt_s.\n";
print "Polaczono z serwerem $opt_s...\n";

$conn->login($opt_u, $opt_p) or expire($conn, "Nie udalo sie zalogowac jako $opt_u.\n");
print "Zalogowano jako $opt_u...\n";

$conn->cwd("/") or expire($conn, "Blad poczatkowego katalogu.\n");
print "Poczatkowy katalog: OK...\n";

$conn->binary() or expire($conn, "Brak trybu binarnego.\n");
print "Tryb binarny: OK...\n";

sub scan_ftp
{
	my $fpt = shift;
	my $path = shift;
	my $rrem = shift;

	my $rdir = $conn->dir($path);

	return unless $rdir and @$rdir;

	for my $f (@$rdir)
  {
  	next if $f =~ m/^d.+\s\.\.?$/;
  	my $n = (split(/\s+/, $f, 9))[8];

    next unless defined $n;

    my $name = '';
    $name = $path . '/' if $path;
    $name .= $n;

    if($opt_i and $name =~ m/$opt_i/)
    {
    	print "ftp: IGNORING $name\n" if $opt_d;
      next;
    }

    next if exists $rrem->{$name};

    my $mdtm = ($conn->mdtm($name) || 0) + $opt_o;
    my $size = $conn->size($name) || 0;
    my $type = substr($f, 0, 1);

    $type =~ s/-/f/;

    warn "ftp: adding $name ($mdtm, $size, $type)\n" if $opt_d;

    $rrem->{$name} = {
    	mdtm => $mdtm,
      size => $size,
      type => $type,
    };

    scan_ftp($conn, $name, $rrem) if $type eq 'd';
  }
}

scan_ftp($conn, '', \%remote);

# synchronizacja

print "Synchronizacja...\n";

my $uptodate = 1;
my $err = 0;

foreach my $file (sort { length($a) <=> length($b) } keys %local)
{
	# brak katalogu na zewnetrzym serwerze
	if($local{$file}->{type} eq 'directory' and !exists $remote{$file})
	{
		if(!$conn->mkdir($file))
		{
			print $conn, "Nie mozna utworzyc $file...";
			$err += 1;
			next;
		}	

		$uptodate = 0;
	}

	# plik
	elsif($local{$file}->{type} eq 'file' and !exists $remote{$file} and $remote{$file} < $local{$file})
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











