#!/usr/bin/perl

use strict;
use POSIX;
use Getopt::Long;

my %color =	(
		OK		=>	{
					high	=> 0x44,
					low	=> 0xcc,
					format	=> '00xx00',
					},
		WARNING		=>	{
					high	=> 0x66,
					low	=> 0xaa,
					format	=> 'xx8800'
					},
		CRITICAL	=>	{
					high	=> 0x99,
					low	=> 0xcc,
					format	=> 'xx0000'
					},
		UNKNOWN		=>	{
					high	=> 0xcc,
					low	=> 0xff,
					format	=> 'ffxx00'
					},
		PENDING		=>	{
					high	=> 0x88,
					low	=> 0xaa,
					format	=> 'xxxxxx'
					}
		);

my $host 	= $ARGV[0];
my $filename	= "$host.png";
my %service;
my @data;
my $X = my $Y	= 1000;		# Canvas width and height (px)
my $Xs		= 5;		# Minimum stroke width (%)
my $Xm		= 85;		# Maximum stroke width (%)
my $Mbw		= 40;		# Maximum percentage of canvas a bezier curve may cover (%)
my $Mcv		= 80;		# Maximum canvas width to use (%)

open (my $in, '-|', "curl -sn http://your_nagios_host_goes.here/nagios/cgi-bin/status.cgi?host=$host.its");

while (<$in>) {
	/img/i and next;
	/service=|nowrap|>(OK|WARNING|CRITICAL|UNKNOWN|PENDING)</ and push @data, $_
}
 
for (my $i=0;$i<@data;$i+=4) {
	$data[$i]	=~ s/<(.*?)>//g;
	$data[$i+1]	=~ s/<(.*?)>//g;
	$data[$i+2]	=~ s/<(.*?)>//g;
	$data[$i+3]	=~ s/<(.*?)>//g;
	my $service	= $data[$i];
	my $status	= $data[$i+1];
	my $duration	= $data[$i+3];
	$duration > 0 or next;
	chomp ($service,$status,$duration);
	$duration	= convert_duration($duration);
	$service{$service}{duration}	= $duration;
	$service{$service}{status}	= $status;
}

my @ss	= reverse sort ssort keys %service;
my $x1	= $service{$ss[$#ss]}{duration};
my $x2	= $service{$ss[0]}{duration};
my $y1	= $Xs/$x1;
my $y2	= $Xm/$x2;
my $m	= ($y2 - $y1)/($x2 - $x1);
my $out	.= header_info();

foreach my $c (sort keys %color) {

	foreach my $s (keys %service) {
		next unless $service{$s}{status} eq $c;
		defined $color{$c}{max} or $color{$c}{max} = $service{$s}{duration};
		defined $color{$c}{min} or $color{$c}{min} = $service{$s}{duration};
		$service{$s}{duration} > $color{$c}{max} and $color{$c}{max} = $service{$s}{duration};
		$service{$s}{duration} < $color{$c}{min} and $color{$c}{min} = $service{$s}{duration};
	}

}

foreach (@ss) {
	my $duration	= $service{$_}{duration};
	my $status	= $service{$_}{status};
	my $brush	= get_brush($x1,$x2,$duration);
	my $paint	= get_palette($duration,$status);
	$out		.= express($brush,$paint);
	print "status $status of duration $duration converted to color $paint and width $brush\n" if $debug;
}

$out .= footer_info();
print $out;

sub ssort {
	return $service{$a}{duration} <=> $service{$b}{duration}
}

sub get_brush {
	my ($min_duration,$max_duration,$duration) = @_;
	return ceil($Xs + (($Xm - $Xs) * ($duration - $min_duration)) / ($max_duration - $min_duration))
}

sub get_palette {
	my ($duration,$status)      = @_;
	if ($color{$status}{max} == $color{$status}{min}) {
		return (frmt(sprintf("%x",(($color{$status}{low} + $color{$status}{high})/2)), $status));
	}
	return frmt((sprintf("%x", (ceil($color{$status}{low} + (($color{$status}{high} - $color{$status}{low}) * ($duration - $color{$status}{min})) / ($color{$status}{max} - $color{$status}{min}))))), $status);
}

sub frmt {
	my ($color, $status) = @_;
	my $format = $color{$status}{format};
	$format =~ s/xx/$color/g;
	return $format;
}

sub express {
	my ($w,$c) = @_;
	my $x1 = int rand(($Mcv/100)*$X)+((5/100)*$X);
	my $x2 = int rand(($Mcv/100)*$X)+((5/100)*$X);;
	my $y1 = int rand((15/100)*$Y);
	my $y2 = int rand((85/100)*$Y);
	my $w1 = int rand((90/100)*$X);
	my $w2 = int rand((90/100)*$X);
	my $w3 = int rand((90/100)*$X);
	my $w4 = int rand((90/100)*$X);
	my $exp = "\t-draw \"stroke-width $w stroke '#$c' bezier $x1,$y1 $w1,$w2 $w3,$w4 $x2,$y2\" \\\n";
	return $exp;
}

sub convert_duration {
	my $duration	= shift @_;
	$duration	=~ s/[dmhs]//g;
	my($d,$h,$m,$s) = 0;
	($d,$h,$m,$s) 	= split(" ",$duration);
	return (($d*24*60)+($h*60)+$m);
}

sub header_info {
	my $exp = "convert -size $X" . "x$Y xc:white -fill none \\\n";
	return $exp;
}

sub footer_info {
	return "\t-blur \"0x1\" $filename\n\n";
}

sub usage {

}
