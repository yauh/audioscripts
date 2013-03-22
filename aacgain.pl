#!/usr/bin/perl -w
# aacgain.pl benötigt ein ausführbares aacgain im pfad
# v1 - 02.05.2008 - initial release
print "### aacgain.pl ###\n";
use strict;
use DirHandle;
use Cwd;
use File::Find;

# Variablendeklaration
my ( %directories, @files, $current_directory, $options, $command, $loopcount );

&show_help
  if $ARGV[0] =~ /^(help|-h|h|--help|\?|-\?)/;  # zeige Hilfetext wenn notwendig

@ARGV = qw(.)
  unless @ARGV; # suche im Startverzeichnis, wenn nichts anderes angegeben wurde
$options = '-a -k';    # Album-Modus, kein clipping, 89db (Standardeinstellung)

# Finde alle Songs im angegebenen Verzeichnis inkl. Unterverzeichnisse
find( \&find_songs, @ARGV );

&process_files;

sub find_songs {
    return
      unless /(\.m4a|\.mp3)/;    # finde nur Dateien, mit entsprechender Endung
    $current_directory = cwd;
    push( @{ $directories{$current_directory} }, $_ );
}

sub process_files {
	my $count = keys %directories;
    foreach my $key ( keys %directories ) {
        @files = qw//;
        foreach ( @{ $directories{$key} } ) {
            push @files, $key . '/' . $_;
        }
        $command = 'aacgain ' . $options;    # konstruiere den aacgain-Befehl
        foreach (@files) {
            $command .= ' ' . "\"$_\"";
        }
        print qx($command);    # führe aacgain aus und zeige die Ausgabe
	print "### finished directory " . ++$loopcount . " of $count\n";
    }
}

sub show_help {
    print "aacgain.pl erlaubt die Mehrfachbearbeitung von MP3/AAC-Dateien.\n";
    print "Hierzu werden alle Unterverzeichnisse nach Dateien durchsucht.\n";
    print "Songs innerhalb eines Ordners werden als Album behandelt.\n";
    print "Syntax: perl aacgain.pl <Verzeichnisname>\n";
    exit;
}
