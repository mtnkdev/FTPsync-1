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