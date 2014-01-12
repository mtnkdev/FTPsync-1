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
use warnings;
use Net::FTP;
use File::Find;
use Pod::Usage;
use Getopt::Std;

use vars qw($opt_s $opt_k $opt_u $opt_l $opt_p $opt_r $opt_h $opt_d $opt_P $opt_i $opt_o);

getopts('i:o:l:s:u:p:r:hkvdP');

if($opt_h)
{
	pod2usage({
		-exitval => 2, 
		-verbose => 2
	});
}

$opt_s ||= 'localhost';
$opt_u ||= 'anonymous';
$opt_p ||= 'someuser@';
$opt_r ||= '/';
$opt_l ||= '.';
$opt_o ||= 0;
$opt_i = qr/$opt_i/ if $opt_i;

my %rem = ();
my %loc = ();

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

    my $r = $loc{$File::Find::name} = {
      mdtm => (stat($File::Find::name))[9],
      size => (stat(_))[7],
      type => -f _ ? 'f' : -d _ ? 'd' : -l $File::Find::name ? 'l' : '?',
    };

    print "local: adding $File::Find::name (", "$r->{mdtm}, $r->{size}, $r->{type})\n" if $opt_d;

  },
}, '.' );

my $ftp = new Net::FTP($opt_s, 
	Debug => $opt_d, 
	Passive => $opt_P,
);

die "Failed to connect to server '$opt_s': $!\n" unless $ftp;
die "Failed to login as $opt_u\n" unless $ftp->login($opt_u, $opt_p);
die "Cannot change directory to $opt_r\n" unless $ftp->cwd($opt_r);

warn "Failed to set binary mode\n" unless $ftp->binary();

#print "connected\n" if $opt_v;

sub scan_ftp
{
	my $fpt = shift;
	my $path = shift;
	my $rrem = shift;

	my $rdir = $ftp->dir($path);

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

    my $mdtm = ($ftp->mdtm($name) || 0) + $opt_o;
    my $size = $ftp->size($name) || 0;
    my $type = substr($f, 0, 1);

    $type =~ s/-/f/;

    warn "ftp: adding $name ($mdtm, $size, $type)\n" if $opt_d;

    $rrem->{$name} = {
    	mdtm => $mdtm,
      size => $size,
      type => $type,
    };

    scan_ftp($ftp, $name, $rrem) if $type eq 'd';
  }
}

scan_ftp($ftp, '', \%rem);












