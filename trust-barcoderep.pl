#!/usr/bin/env perl

use strict ;
use warnings ;

die "Usage: ./trust-barcoderep.pl xxx_cdr3.out [OPTIONS] > trust_barcode_report.tsv\n". 
	"OPTIONS:\n".
	"\t-a xxx_annot.fa: TRUST4's annotation file. (default: not used)\n".
	"\t--noPartial: do not including partial CDR3 in report. (default: include partial)\n"
	if ( @ARGV == 0 ) ;

my %cdr3 ;  

# Copied from http://www.wellho.net/resources/ex.php4?item=p212/3to3
my %DnaToAa = (
		'TCA' => 'S',    # Serine
		'TCC' => 'S',    # Serine
		'TCG' => 'S',    # Serine
		'TCT' => 'S',    # Serine
		'TTC' => 'F',    # Phenylalanine
		'TTT' => 'F',    # Phenylalanine
		'TTA' => 'L',    # Leucine
		'TTG' => 'L',    # Leucine
		'TAC' => 'Y',    # Tyrosine
		'TAT' => 'Y',    # Tyrosine
		'TAA' => '_',    # Stop
		'TAG' => '_',    # Stop
		'TGC' => 'C',    # Cysteine
		'TGT' => 'C',    # Cysteine
		'TGA' => '_',    # Stop
		'TGG' => 'W',    # Tryptophan
		'CTA' => 'L',    # Leucine
		'CTC' => 'L',    # Leucine
		'CTG' => 'L',    # Leucine
		'CTT' => 'L',    # Leucine
		'CCA' => 'P',    # Proline
		'CCC' => 'P',    # Proline
		'CCG' => 'P',    # Proline
		'CCT' => 'P',    # Proline
		'CAC' => 'H',    # Histidine
		'CAT' => 'H',    # Histidine
		'CAA' => 'Q',    # Glutamine
		'CAG' => 'Q',    # Glutamine
		'CGA' => 'R',    # Arginine
		'CGC' => 'R',    # Arginine
		'CGG' => 'R',    # Arginine
		'CGT' => 'R',    # Arginine
		'ATA' => 'I',    # Isoleucine
		'ATC' => 'I',    # Isoleucine
		'ATT' => 'I',    # Isoleucine
		'ATG' => 'M',    # Methionine
		'ACA' => 'T',    # Threonine
		'ACC' => 'T',    # Threonine
		'ACG' => 'T',    # Threonine
		'ACT' => 'T',    # Threonine
		'AAC' => 'N',    # Asparagine
		'AAT' => 'N',    # Asparagine
		'AAA' => 'K',    # Lysine
		'AAG' => 'K',    # Lysine
		'AGC' => 'S',    # Serine
		'AGT' => 'S',    # Serine
		'AGA' => 'R',    # Arginine
		'AGG' => 'R',    # Arginine
		'GTA' => 'V',    # Valine
		'GTC' => 'V',    # Valine
		'GTG' => 'V',    # Valine
		'GTT' => 'V',    # Valine
		'GCA' => 'A',    # Alanine
		'GCC' => 'A',    # Alanine
		'GCG' => 'A',    # Alanine
		'GCT' => 'A',    # Alanine
		'GAC' => 'D',    # Aspartic Acid
		'GAT' => 'D',    # Aspartic Acid
		'GAA' => 'E',    # Glutamic Acid
		'GAG' => 'E',    # Glutamic Acid
		'GGA' => 'G',    # Glycine
		'GGC' => 'G',    # Glycine
		'GGG' => 'G',    # Glycine
		'GGT' => 'G',    # Glycine
		);

sub GetChainType
{
	foreach my $g (@_)
	{
		if ( $g =~ /^IGH/ )
		{
			return 0 ;
		}
		elsif ( $g =~ /^IG/ )
		{
			return 0 ;
		}
		elsif ( $g =~ /^TR/ )
		{
			return 2 ;
		}
	}
	return -1 ;
}

sub GetDetailChainTypeFromGeneName
{
	my $g = $_[0] ;
	if ( $g =~ /^IGH/ )
	{
		return 0 ;
	}
	elsif ( $g =~ /^IGK/ )
	{
		return 1 ;
	}
	elsif ( $g =~ /^IGL/ )
	{
		return 2 ;
	}
	elsif ( $g =~ /^TRA/ )
	{
		return 3 ;
	}
	elsif ( $g =~ /^TRB/ )
	{
		return 4 ;
	}
	elsif ( $g =~ /^TRG/ )
	{
		return 5 ;
	}
	elsif ( $g =~ /^TRD/ )
	{
		return 6 ;
	}
	
	return -1 ;
}

sub GetDetailChainType
{
	my $i ;
	for ( $i = 1 ; $i <= 2 ; ++$i )
	{
		my $type = GetDetailChainTypeFromGeneName( $_[$i] ) ;
		return $type if ( $type != -1 ) ;
	}
	# In the case of only V gene is available.
	my $type = GetDetailChainTypeFromGeneName( $_[0] ) ;
	return $type ;
}

sub GetCellType
{
	if ( $_[0] <= 2 )
	{
		return 0 ; # B
	}
	elsif ( $_[0] <= 4 )
	{
		return 1 ; # abT
	}
	elsif ( $_[0] <= 6 ) 
	{
		return 2 ; # gdT
	}
	return -1 ;
}

# Use input V, J, C gene to report back the C gene if it is missing.
sub InferConstantGene
{
	my $ret = $_[2] ;
	my $i ;
	
	if ($_[2] ne "*")
	{
		for ( $i = 0 ; $i <= 1 ; ++$i )
		{
			next if ( $_[$i] eq "*" ) ;
			if ( !($_[$i] =~ /^IGH/) )
			{
				$ret = substr($ret, 0, 4 );
				last ;
			}
		}
		
		return $ret ;
	}
	
	# For TRA and TRD gene, we don't infer its constant gene.
	if ($_[0] =~ /^TR[AD]/ || $_[1] eq "*")
	{
		return $ret ;
	}

	for ( $i = 1 ; $i >= 0 ; --$i )
	{
		next if ( $_[$i] eq "*" ) ;
		if ( $_[$i] =~ /^IGH/ )
		{
			return $ret ;
		}
		my $prefix = substr( $_[$i], 0, 3 ) ;
		
		return $prefix."C" ; 
	}
	return $ret ;
}

my %aaPriority = ("out_of_frame"=>1, "partial"=>0) ;
# Test whether a is better than b.
sub BetterAA
{
	my $a = $_[0] ;
	my $b = $_[1] ;
	
	if (defined $aaPriority{$a} && defined $aaPriority{$b})
	{
		return $aaPriority{$a} - $aaPriority{$b} ;
	}
	elsif (defined $aaPriority{$a})
	{
		return -1 ;
	}
	elsif (defined $aaPriority{$b})
	{
		return 1 ;
	}
	else
	{
		return 0 ;
	}
}

my $i ;
my $reportPartial = 1 ;
my $annotFile = "" ;
for ( $i = 1 ; $i < @ARGV ; ++$i )
{
	if ( $ARGV[$i] eq "--noPartial" )
	{
		$reportPartial = 0 ;
	}
	elsif ( $ARGV[$i] eq "-a" )
	{
		$annotFile = $ARGV[$i + 1] ;
		++$i ;
	}
	else
	{
		die "Unknown option ", $ARGV[$i], "\n" ;
	}
}

# Store whether there is good assemblies that haven't got CDR3 from the annottation file.
my %barcodeChainInAnnot ; 
if ( $annotFile ne "" )
{
	open FP1, $annotFile ;
	while ( <FP1> )
	{
		next if ( !/^>/ ) ;
		my @cols = split /\s/, $_ ;

		my @vCoord ;
		my @dCoord ;
		my @jCoord ;
		my @cdr3Coord ;

		if ( $cols[3] =~ /\(([0-9]+?)\):\(([0-9]+?)-([0-9]+?)\):\(([0-9]+?)-([0-9]+?)\):([0-9\.]+)/ )
		{
			#print($cols[3], "\t", $1, "\t", $6, "\n") ;
			@vCoord = ($1, $2, $3, $4, $5, $6) ;
		}
		else
		{
			#die "Wrong format $header\n" ;
			@vCoord = (-1, -1, -1, -1, -1, 0)
		}
		
		if ( $cols[5] =~ /\(([0-9]+?)\):\(([0-9]+?)-([0-9]+?)\):\(([0-9]+?)-([0-9]+?)\):([0-9\.]+)/ )
		{
			@jCoord = ($1, $2, $3, $4, $5, $6) ;
		}
		else
		{
			#die "Wrong format $header\n" ;
			@jCoord = (-1, -1, -1, -1, -1, 0)
		}
		
		my $chainType = -1 ;
		if ( $vCoord[2] - $vCoord[1] >= 50 && $vCoord[5] >= 0.95 )
		{
			$chainType = GetDetailChainTypeFromGeneName( substr($cols[3], 0, 3) ) ; 		
		}
		elsif ($jCoord[2] - $jCoord[1] >= $jCoord[0] * 0.66 && $jCoord[5] >= 0.95)
		{
			$chainType = GetDetailChainTypeFromGeneName( substr($cols[5], 0, 3) ) ; 		
		}

		if ( $chainType != -1 )
		{
			my @cols2 = split/_/, substr($cols[0], 1) ;
			my $barcode = join( "_", @cols2[0..scalar(@cols2)-2] ) ;
			$barcodeChainInAnnot{ $barcode."_".$chainType } = $chainType ;
		}
		
	}
	close FP1 ;
}

# collect the read count for each chain from assembly id.
open FP1, $ARGV[0] ;
my %barcodeChainAbund ; 
my %barcodeChainRepresentAbund ;
my %barcodeChainInfo ;
my %barcodeShownup ;
my %barcodeChainAa ;
my @barcodeList ;

# Read in the report, store the information for each barcode.
while ( <FP1> )
{
	chomp ;
	my @cols = split ;
	next if ( $reportPartial == 0 && $cols[9] == 0 ) ;

	my $assemblyId = $cols[0] ;
	my $vgene = (split /,/, $cols[2])[0] ;
	my $dgene = (split /,/, $cols[3])[0] ;
	my $jgene = (split /,/, $cols[4])[0] ;
	my $cgene = (split /,/, $cols[5])[0] ;
	#$cgene = InferConstantGene( $vgene, $jgene, $cgene ) ;

	my @cols2 = split/_/, $assemblyId ;
	my $barcode = join( "_", @cols2[0..scalar(@cols2)-2] ) ;
	my $key = $barcode."_".GetDetailChainType( $vgene, $jgene, $cgene ) ;
	my $aa ;
	
	if ( !defined $barcodeShownup{ $barcode } )
	{
		$barcodeShownup{ $barcode } = 1 ;
		push @barcodeList, $barcode ;
	}

	if ( $cols[9] == 0 )
	{
		$aa = "partial" ;
	}
	else
	{
		if ( length( $cols[8] ) % 3 != 0 )
		{
			$aa = "out_of_frame" ;
		}
		else
		{
			my $len = length( $cols[8] ) ;
			my $s = uc( $cols[8] ) ;
			for ( my $i = 0 ; $i < $len ; $i += 3 )
			{
				if ( !defined $DnaToAa{ substr( $s, $i, 3 ) } )
				{	
					$aa .= "?" ;
				}
				else
				{
					$aa .= $DnaToAa{ substr( $s, $i, 3 ) } ;
				}
			}
		}
	}

	if ( defined $barcodeChainAbund{ $key } )
	{
		if ( BetterAA($aa, $barcodeChainAa{$key}) > 0 || 
			( $cols[10] > $barcodeChainRepresentAbund{ $key } && BetterAA($aa, $barcodeChainAa{$key}) == 0 ) )
		{
			$barcodeChainRepresentAbund{$key} = $cols[10] ;
			$barcodeChainAa{$key} = $aa ;
			$barcodeChainInfo{ $key } = join( ",", ($vgene, $dgene, $jgene, $cgene, $cols[8], $aa, $cols[10], $cols[11] ) ) ;
		}
		$barcodeChainAbund{ $key } += $cols[10] ;
	}
	else
	{
		$barcodeChainAbund{ $key } = $cols[10] ;
		$barcodeChainRepresentAbund{$key} = $cols[10] ;
		$barcodeChainAa{$key} = $aa ;
		$barcodeChainInfo{ $key } = join( ",", ($vgene, $dgene, $jgene, $cgene, $cols[8], $aa, $cols[10], $cols[11]) ) ;
	}
	
	#if ($barcode eq "GTACTTTGTACCAGTT-1")
	#{
	#	print($barcode, " ", $key, " ", $barcodeChainAbund{$key}, " ", $barcodeChainAa{$key}, "\n")
	#}
}
close FP1 ;

# Output what we collected.
print( "#barcode\tcell_type\tchain1\tchain2\n" ) ;

foreach my $barcode (@barcodeList )
{
	# Determine type
	my $i ;
	my $mainType ; # 0-IG, 1-TRA/B, 2-TRG/D
	my $cellType ;
	my $max = -1 ;
	my $maxTag = -1 ;
	my $chain1 = "*" ;
	my $chain2 = "*" ;
	for ( $i = 0 ; $i < 7 ; ++$i )
	{
		my $key = $barcode."_".$i ;
		# gdT should have more stringent criterion.
		last if ($i >= 5 && $maxTag != -1 ) ;

		if ( defined $barcodeChainAbund{ $key } && $barcodeChainAbund{ $key } > $max )
		{
			$max = $barcodeChainAbund{ $key } ;
			$maxTag = $i ;
		}
	}
	
	if ( $maxTag >= 5 && $annotFile ne "" )
	{
		# use annotation file to further file gdT
		for ( $i = 0 ; $i < 5 ; ++$i )
		{
			last if ( defined $barcodeChainInAnnot{$barcode."_".$i} ) ;
		}
		next if ( $i < 5 ) ;
	}

	if ( $maxTag <= 2 )
	{
		$mainType = 0 ;
		my $keyH = $barcode."_0" ;
		my $keyK = $barcode."_1" ;
		my $keyL = $barcode."_2" ;
		$chain1 = $barcodeChainInfo{ $keyH } if ( defined $barcodeChainInfo{ $keyH } ) ;

		if ( defined $barcodeChainInfo{ $keyK } && defined $barcodeChainInfo{ $keyL } )
		{
			if ( $barcodeChainAbund{ $keyK } >= $barcodeChainAbund{ $keyL } )
			{
				$chain2 = $barcodeChainInfo{ $keyK } ;
			}
			else
			{
				$chain2 = $barcodeChainInfo{ $keyL } ;
			}
		}
		elsif ( defined $barcodeChainInfo{ $keyK } )
		{
			$chain2 = $barcodeChainInfo{ $keyK } ;
		}
		elsif ( defined $barcodeChainInfo{ $keyL } )
		{
			$chain2 = $barcodeChainInfo{ $keyL } ;
		}

		$cellType = "B" ;
	}
	else
	{
		my $key1 ;
		my $key2 ;
		if ( $maxTag <= 4 )
		{
			$key1 = $barcode."_4" ;
			$key2 = $barcode."_3" ;
			$cellType = "abT" ;
		}
		elsif ( $maxTag <= 6 )
		{
			$key1 = $barcode."_6" ;
			$key2 = $barcode."_5" ;
			$cellType = "gdT" ;
		}
		$chain1 = $barcodeChainInfo{ $key1 } if ( defined $barcodeChainInfo{ $key1 } ) ;
		$chain2 = $barcodeChainInfo{ $key2 } if ( defined $barcodeChainInfo{ $key2 } ) ;
	}
	print( join( "\t", ($barcode, $cellType, $chain1, $chain2 ) ), "\n" ) ;
}
