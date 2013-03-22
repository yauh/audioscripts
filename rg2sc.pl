#!/usr/bin/perl
#
# MP3 ReplayGain to iTunes SoundCheck converter
# Changes RG info stored in APEv2 or ID3v2 tags to iTunNORM id3v2 COMM tag
#
# (c) 2009 Richard van den Berg <richard@vdberg.org>
# Distrubuted under the GPLv3, see http://www.gnu.org/copyleft/gpl.html
# Latest version avaiable from http://www.vdberg.org/~richard/rg2sc.html
#
# 2009/04/12 v1.0: initial version
# 2009/04/15 v1.1: take unknown values from existing iTunNORM tag
# 2009/04/17 v1.2: add -d switch to delete iTunNORM tag

use File::Basename;
use Getopt::Std;
use MP3::Info;
use MP3::Tag;

$version="1.2";

$verbose=$ag=$reset=$delete=$keep=0;
$rgn="track";
getopts('havntd',\%opt) || exit;
&usage     if($opt{'h'});
$verbose=1 if($opt{'v'});
$keep=1    if($opt{'n'});
$reset=1   if($opt{'t'});
$delete=1  if($opt{'d'});
if($opt{'a'}) {
	$ag=1;
	$rgn="album";
}

if($keep && $delete) {
	print "The -n and -d switches are mutually exclusive.";
	exit 1;
}

mainloop: while($file=shift @ARGV) {
	print "Processing $file\n" if($verbose);
	@scv=();
	$scv[4]=$scv[5]=$scv[8]=$scv[9]="00024CA8";
	$scv[6]=$scv[7]="00007FFF";

	$info=get_mp3tag($file,2,2,1);

	unless($info) {
		print "Can't get_mp3tag for $file: $!\n";
		next;
	}

	$ts=(stat($file))[9] if($reset);

	if($ag) {
		$rg=$info->{REPLAYGAIN_ALBUM_GAIN};
		$pk=$info->{REPLAYGAIN_ALBUM_PEAK};
	} else {
		$rg=$info->{REPLAYGAIN_TRACK_GAIN};
		$pk=$info->{REPLAYGAIN_TRACK_PEAK};
	}

	if($rg eq "") {
		print "No $rgn ReplayGain information found in $file\n";
		next;
	}

	print "Found $rgn RG value of $rg\n" if($verbose);

	$mp3 = MP3::Tag->new($file);

	unless ($mp3) {
		print "Couldn't use MP3::TAG on $mp3file: $!\n";
		next;
	}

	@tags = $mp3->get_tags();
	if (exists $mp3->{ID3v2}) {
		print "Using old ID3v2 tag\n" if($verbose && !$delete);
		$id3 = $mp3->{ID3v2};
	} else {
		print "Creating new ID3v2 tag\n" if($verbose && !$delete);
		$id3 = $mp3->new_tag("ID3v2");
		if (exists $mp3->{ID3v1}) {
			$v1=$mp3->{ID3v1};
			$id3->add_frame("TIT2",$tmp) if(($tmp=$v1->title) ne "");
			$id3->add_frame("TPE1",$tmp) if(($tmp=$v1->artist) ne "");
			$id3->add_frame("TALB",$tmp) if(($tmp=$v1->album) ne "");
			$id3->add_frame("TRCK",$tmp) if(($tmp=$v1->track) ne "");
			$id3->add_frame("TYER",$tmp) if(($tmp=$v1->year) ne "");
			$id3->add_frame("TCON",$tmp) if(($tmp=$v1->genre) ne "");
			$id3->add_frame("COMM", "XXX", "ID3v1 Comment", $tmp) if(($tmp=$v1->comment) ne "");
		}
	}
	
	$frames = $id3->supported_frames();
	if (!exists $frames->{COMM}) {
		print "Something is wrong, COMM is not a supported frame!\n";
		exit 2;
	}

	$frameids = $id3->get_frame_ids();
	$found=0;
	if (exists $$frameids{COMM}) {
		# Find and replace existing iTunNORM frame
		$i=0;
		$comm="COMM";
		findloop: while(!$found) {
			($info, $name) = $id3->get_frame($comm);
			last findloop if(!defined $info);
			if(ref $info && $info->{Description} eq "iTunNORM") {
				$found=1;
				if($keep) {
					print "Not replacing existing iTunNORM entry\n" if($verbose);
					$mp3->close();
					next mainloop;
				}
				if($delete) {
					print "Removing iTunNORM tag\n" if($verbose);
					$id3->remove_frame($comm);
				} else {
					@scv=split(' ',$info->{Text});
					$sc=" ".join(" ",convertReplayGainToSoundCheck($rg,$pk));
					print "Replacing existing iTunNORM entry\n" if($verbose);
					$id3->change_frame($comm, "eng", "iTunNORM", $sc);
				}
			}
			$comm=sprintf("COMM%02d",++$i);
		}
	}
	if(!$delete) {
		if(!$found) {
			$sc=" ".join(" ",convertReplayGainToSoundCheck($rg,$pk));
			print "Creating new iTunNORM entry\n" if($verbose);
			$id3->add_frame("COMM", "eng", "iTunNORM", $sc);
		}
	}
	$id3->write_tag();
	$mp3->close();

	utime(time,$ts,$file) if($reset);

	print "Successfully added SC tag to $file\n" if($verbose && !$delete);
}

exit;

sub usage {
	$name=basename($0);
	print "rg2sc($version): write iTunes SoundCheck tag to mp3 based on ReplayGain tags\n\n";
	print "Usage: $name [-h] [-a] [-v] <file1.mp3> .. <filen.mp3>\n";
	print "        -h  print this help page\n";
	print "        -a  use album ReplayGain info instead of track info\n";
	print "        -n  do not overwrite existing SoundCheck tag\n";
	print "        -d  delete existing SoundCheck tag\n";
	print "        -t  reset last modified timestamp of altered files\n";
	print "        -v  be verbose\n";
}

# Code below adapted from
# http://projects.robinbowes.com/flac2mp3/trac/ticket/30

sub convertReplayGainToSoundCheck {
	my ($gain, $peak) = @_;
	if ( $gain =~ /(.*)\s+dB$/ ) {
    		$gain = $1;
	}
	my @soundcheck;
	@soundcheck[0,2] = ( gain2sc($gain, 1000), gain2sc($gain, 2500) );
	@soundcheck[1,3] = @soundcheck[0,2];
	# bogus values for now -- however, these don't seem to be used AFAIK
	@soundcheck[4,5,6,7,8,9] = @scv[4,5,6,7,8,9];
	return @soundcheck;
}

sub gain2sc {
	my ($gain, $base) = @_;
	my $result = round((10 ** (-$gain / 10)) * $base);

        if ($result > 65534) {
                $result = 65534;
        }

        return decimalToASCIIHex($result);
}

sub round {
	my $number = shift;
	return int($number + .5 * ($number <=> 0));
}

sub decimalToASCIIHex {
	return sprintf("%08X", shift);
}

