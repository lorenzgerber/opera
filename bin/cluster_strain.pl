#!/usr/bin/perl
use warnings "all";
use Statistics::Basic qw(:all);
use Statistics::R;
#use Math::GammaFunction qw(:all);
#use Math::GammaFunction qw(:all);


my ($end_time, $start_time);
$start_time = time;

my $R = Statistics::R->new();
my @confidance_interval;
#compute_confidance_interval(4.8, 8);
#print STDERR "@confidance_interval\n";
#use POSIX ();
#use POSIX qw(setsid);
#use POSIX qw(:errno_h :fcntl_h);


#$a = log_gamma(5);

#exit(0);

my ($species_dir, $reference_size, $dispersion_value, $step_dispersion_value_increase, $opera_ms_dir) = @ARGV;

my $coverage_file = "$species_dir/contigs_340_80";

my %contig_info = ();

open FILE, "$coverage_file" or die $!;
my $header = <FILE>;chop $header;
#
my @line = split (/ /, $header);
my $window_size = $line[3];
my ( $mean, $stddev, $median, $nb_exluded_window);
#my (@window_count, @window_count_filtered);
while (<FILE>) {
    chomp $_;	
    #The line with the contig ID
    @line = split (/\t/, $_);
    $contig = $line[0];
    $length = $line[1];
    $nb_window = $line[4];
    #The line with number of arriving reads
    $read_count = <FILE>;chop $read_count;
    #print STDERR $read_count."\t|".$nb_window."|\t".$window_size."\n";<STDIN>;
    #Skip the next line that contian the windows (need to compute the variance latter)
    $str = <FILE>;chop $str;my @window_count = split(/ /, $str);
    #print STDERR $contig."\t".$length."\t"."@window_count"."\n";<STDIN>;
    $mean   = int(mean(@window_count)); # array refs are ok too
    $median   = median(@window_count); # array refs are ok too
    #$stddev   = stddev( @window_count );
    #$variance = variance (@window_count); 
    
    #print STDERR " *** $contig\n @window_count\n$median $mean $stddev\n";<STDIN>;
    $contig_info{$contig} = {
	#"READ_COUNT", $read_count, 
	"COV", ($read_count/($nb_window*$window_size)), 
	    "LENGTH", $length, 
	    #
	    "WINDOW", \@window_count,
	    
	    #
	    "MEAN_READ_COUNT", $mean,
	    "MEDIAN_READ_COUNT", $median,
	    #"STDDEV_COV", $stddev,
	    #"VARIANCE_COV", $variance,

	    "STRAIN_ID", 0,
	    "SHARED_CONTIG", 0
    };
}
close(FILE);


#get the initial mean
my $sum_contig_length = 0;
my $sum_read_count = 0;
my @contig_mean_cov = ();
my $window_count = [];
my $min_contig_cov = 0;
#
my $MAX_CONTIG_COV = 100000;
#
foreach $contig (sort {$contig_info{$b}->{"MEAN_READ_COUNT"} <=> $contig_info{$a}->{"MEAN_READ_COUNT"}} keys %contig_info){
    #last if($sum_contig_length > $reference_size);
    $contig_read_count = $contig_info{$contig}->{"MEAN_READ_COUNT"};
    next if($contig_read_count > $MAX_CONTIG_COV);
    
    push(@contig_mean_cov,  $contig_read_count);
    push(@{$window_count}, @{$contig_info{$contig}->{"WINDOW"}});#if($contig_info{$contig}->{"MEAN_READ_COUNT"} <7000);
    $sum_read_count += $contig_read_count;
    $sum_contig_length += $contig_info{$contig}->{"LENGTH"};
    $min_contig_cov = $contig_read_count;
}


#Identify suitable mode:
#The highest coverage mode should contain large number of contigs as it must contigs of the histes abundance species
#The mode identificatin can be affected by widows with outlier coverage

my ($mode, $strain_mean_value, $strain_var, $sequence_size_in_highest_mode_distribution);
my $mode_accepted = -1;
my $nb_window_in_dist;
my $coverrage_sun_in_dist;
my $window_count_in_h_mode_distribution;
while($mode_accepted == -1){
    
    $mode = compute_mode($window_count);

    #Select the higher mode that covers a significant number of contigs
    print STDERR " *** MODE DETECTED @{$mode}\n";

    if(@{$mode} == 1){
	#update the smoothing parameter
	next;
    }

    for(my $i = @{$mode} - 1; $i >= 0 && $mode_accepted == -1; $i--){
	
	
	$curr_mode = $mode->[$i];
	next if(index($curr_mode, "[") != -1);
	
	#get the dispersion from the highest mode
	$strain_mean_value = estimate_mean($curr_mode, $dispersion_value);
	#get the confidence interval
	compute_confidance_interval($strain_mean_value, $dispersion_value);

	print STDERR "MEAN ESTIMATION BASED " . $strain_mean_value . "ON MODE " . $curr_mode . " AND DISPERTION ". $dispersion_value . "\n";
	print STDERR "ESTIMATED CONFIDANCE INTERVAL FOR  " . $curr_mode. " -> [@confidance_interval]" . "\n";#<STDIN>;
	
	#
	@{$window_count_in_h_mode_distribution} = ();
	$nb_window_in_dist = 0;$coverage_sum_in_dist = 0;
	foreach $contig (sort {$contig_info{$b}->{"MEAN_READ_COUNT"} <=> $contig_info{$a}->{"MEAN_READ_COUNT"}} keys %contig_info){
	    $contig_read_count = $contig_info{$contig}->{"MEAN_READ_COUNT"};
	    #$probability = compute_probability( $strain_mean_cov, $dispersion_value, $contig_mean_cov);
	    
	    if($confidance_interval[0] < $contig_read_count && $contig_read_count < $confidance_interval[1]){
		foreach $c (@{$contig_info{$contig}->{"WINDOW"}}){
		    $coverage_sum_in_dist += $c;
		    $nb_window_in_dist ++;
		}
		push(@{$window_count_in_h_mode_distribution}, @{$contig_info{$contig}->{"WINDOW"}});
	    }
	}
	$sequence_size_in_h_mode_distribution =  $nb_window_in_dist * $window_size;#@{$window_count_in_h_mode_distribution} * $window_size;
	$mean_cov_in_dist = $coverage_sum_in_dist / $nb_window_in_dist;
	print STDERR " *** Mode distribution evaluation : " . $curr_mode . " sequence_size_in_h_mode_distribution: $sequence_size_in_h_mode_distribution " . "mean_cov_in_dist $mean_cov_in_dist ". " estimated_mean_value $strain_mean_value " . "mean_cov_in_dist/estimated_mean_value " . ($mean_cov_in_dist  / $strain_mean_value) . "\n";#<STDIN>;
	
	if((0.70 < ($mean_cov_in_dist  / $strain_mean_value) && ($mean_cov_in_dist  / $strain_mean_value) < 1.3) && #the mean estimate and the mean obtain by the confidance interval are comparable => good fitting
	    $sequence_size_in_h_mode_distribution > $reference_size*0.5){
	    $mode_accepted = $i;
	    print STDERR " *** *** *** MODE ACCEPTED $i $mode->[$i]\n\n";
	    #Get the count in the confidance interval
	    my @tmp_count = ();
	    
	}
		
	#my @tmp_count = ();
	#if(0 && $sequence_size_in_h_mode_distribution < $reference_size*0.5){
	    #filter $window_count to remove any value higher than the mode
	 #   foreach $count (@{$window_count}){
	#	push(@tmp_count, $count) if($count < $mode->[1])
	 #   }
	  #  $window_count = \@tmp_count;
	#}
	#else{
	#    $mode_accepted = 1;
	#}
    }
    if($mode_accepted == -1){
	$dispersion_value += $step_dispersion_value_increase;
    }
}


#Restimation of R
#$strain_var = int(variance ($window_count));
$strain_var = int(variance ($window_count_in_h_mode_distribution));
		  
$dispersion_value = ($strain_mean_value * $strain_mean_value) / ($strain_var - $strain_mean_value);
print STDERR "DISPERTION VALUE " . $dispersion_value . " ESTIMATED USING " . $strain_mean_value . " AND VARIANCE |". $strain_var . "|\n";
#Restimate the mean using the restimated R value
$strain_mean_value = estimate_mean($mode->[$mode_accepted], $dispersion_value);

print STDERR "MEAN ESTIMATION BASED " . $strain_mean_value . "\t". $strain_var . "\t|" . $dispersion_value . "|\n";

#Get the confiance interval for the strain coverage
compute_confidance_interval($strain_mean_value, $dispersion_value);
#To remove repeat
#if($confidance_interval[1] > $strain_mean_value * 1.75){
#    $confidance_interval[1] = $strain_mean_value * 1.75;
#}
print STDERR $strain_mean_value . "\t". $dispersion_value . "\t" . "[@confidance_interval]" . "\t" . ($sum_read_count / (@contig_mean_cov+0)) . "\t" . $min_contig_cov . "\n";#<STDIN>;

#Score each contig and assign a strain to it
#my $PROBABILITY_THRESHOLD = 0.95;
open(OUT, ">contig_coverage_evaluation.dat");
my @window_in_inter = ();my @window_outside_inter = ();
foreach $contig (sort {$contig_info{$b}->{"MEAN_READ_COUNT"} <=> $contig_info{$a}->{"MEAN_READ_COUNT"}} keys %contig_info){
    $contig_mean_cov = $contig_info{$contig}->{"MEAN_READ_COUNT"};
    #$probability = compute_probability( $strain_mean_cov, $dispersion_value, $contig_mean_cov);

    @window_in_inter = (); @window_outside_inter = ();
    
    $cmp = 0;
    foreach $window_coverage (@{$contig_info{$contig}->{"WINDOW"}}){
	if($confidance_interval[0] < $window_coverage){# && $window_coverage < $confidance_interval[1]){
	    push(@window_in_inter, $cmp);
	}
	else{
	    push(@window_outside_inter, $cmp);
	}
	$cmp++;
    }
    
    
    if($confidance_interval[0] < $contig_mean_cov && $contig_mean_cov < $confidance_interval[1]){
	$contig_info{$contig}->{"STRAIN_ID"} = 1;
    }
    else{
	if($contig_mean_cov < $strain_mean_value){
	    $contig_info{$contig}->{"STRAIN_ID"} = 2;
	}
    }

    #if(@window_in_inter != 0 && @window_outside_inter != 0 && $contig_info{$contig}->{"STRAIN_ID"} == 1){
    #$chimeric_rate = @window_in_inter / (@window_in_inter + @window_outside_inter);
    #print OUT $contig . "\t" . $chimeric_rate . "\t" . (join(",", @window_outside_inter)) . "\n";
    #}
    
}
close(OUT);

#exit(0);

#filter contig base on reference mapping
#contig that share similar sequence are filetred out if they are predicted to belong to the same cluster
#filter_mapping();


#Construct the data for OPERA-LG
my @EDGE_ID_INFO = (300, 1000, 2000, 5000, 15000, 40000);
my @strain_list = (1, 2);
my ($species_contig_file, $strain_contig_file);
foreach $strain_id (@strain_list){
    $strain_dir = "$species_dir/STRAIN_$strain_id";
    `mkdir $strain_dir` if(! -d $strain_dir);
    
    #Generate the opera_lg config file
    my $OPERA_LG_CONFIG;
    open($OPERA_LG_CONFIG, ">$strain_dir/opera.config");
    print $OPERA_LG_CONFIG "output_folder=$strain_dir\n";
    print $OPERA_LG_CONFIG "contig_file=$strain_dir/contigs.fa\n";
    print $OPERA_LG_CONFIG 
	"keep_repeat=yes" . "\n" . 
	"filter_repeat=no" . "\n" . 
	"cluster_threshold=1" . "\n" . #How to handle the cluster threshold 
	"cluster_increased_step=5" . "\n" . 
	"kmer=60" . "\n";
    
    #get the strain edges
    for(my $edge_id = 0; $edge_id <= 5; $edge_id++){
	extract_edge($edge_id, $strain_id, $OPERA_LG_CONFIG);
    }
    close($OPERA_LG_CONFIG);
}

#generate the strain contig file
foreach $strain_id (@strain_list){
    $strain_dir = "$species_dir/STRAIN_$strain_id";
    #
    $species_contig_file = "$species_dir/contigs.fa";
    open(FILE, $species_contig_file);
    $strain_contig_file = "$strain_dir/contigs.fa";
    open(OUT, ">$strain_contig_file");
    #Generate the strain contig file
    while(<FILE>){
	if($_ =~ m/>(.*)/){
	    $c = $1;@tmp = split(/\s+/, $c);$c = $tmp[0];
	    #print STDERR " *** Contig name $c\n";<STDIN>;
	    $seq = <FILE>;
	    if($contig_info{$c}->{"STRAIN_ID"} ne "NA" && ($contig_info{$c}->{"STRAIN_ID"} == $strain_id || $contig_info{$c}->{"SHARED_CONTIG"})){
		print OUT ">$c\n";
		print OUT $seq;
	    }
	}
    }
    close(OUT);
}

#Indicate the contig that have been slected and their assignation
open(OUT, ">$species_dir/strain_cluster.dat");
open(OUT_W, ">$species_dir/window_distibution.dat");
foreach $contig (keys %contig_info){
    if($contig_info{$contig}->{"STRAIN_ID"} ne "NA"){
	print OUT $contig . "\t" . $contig_info{$contig}->{"MEAN_READ_COUNT"} . "\t" . $contig_info{$contig}->{"STRAIN_ID"} . "\t" . $contig_info{$contig}->{"SHARED_CONTIG"} . "\n";
	print OUT_W "" . join("\n", @{$contig_info{$contig}->{"WINDOW"}}) . "\n";
    }
}
$end_time = time;
my @tmp = split(/\//,$species_dir);
my $species_name = $tmp[-1];
print STDOUT "*** ***  Clustering $species_name Elapsed time: " . ($end_time - $start_time) . "\n";

#Run OPERA-LG
foreach $strain_id (@strain_list){
    #next if($strain_id == 1);
    $start_time = time;
    $strain_dir = "$species_dir/STRAIN_$strain_id";
    run_exe("$opera_ms_dir/OPERA-LG/bin/OPERA-LG $strain_dir/opera.config  > $strain_dir/log.txt");
    $end_time = time;
    my @tmp = split(/\//,$species_dir);
    my $species_name = $tmp[-1];
    print STDOUT "*** ***  Assembly $species_name $strain_id, Elapsed time: " . ($end_time - $start_time) . "\n";
}


sub extract_edge{
    my ($edge_id, $strain_id, $OPERA_LG_CONFIG) = @_;

    my $edge_file = "$species_dir/pairedEdges_i$edge_id/pairedEdges_i$edge_id";
    #my $edge_file = "$species_dir/pairedge_i$edge_id/pairedEdges_i$edge_id";
    print STDERR " *** Analyzing edge file $edge_file\n";
    open(FILE, $edge_file);
    #
    my $strain_edge_dir = "$strain_dir/pairedEdges_i$edge_id";
    run_exe("mkdir $strain_edge_dir") if(!-d $strain_edge_dir);
    my $strain_edge_file = "$strain_edge_dir/pairedEdges_i$edge_id";
    open(OUT, ">$strain_edge_file");
    `touch $strain_edge_dir/lib.txt`;
    #
    print $OPERA_LG_CONFIG "[LIB]\n";
    print $OPERA_LG_CONFIG "map_type=opera\n";
    print $OPERA_LG_CONFIG "map_file=$strain_edge_file\n";
    print $OPERA_LG_CONFIG "lib_mean=" . ($EDGE_ID_INFO[$edge_id]) . "\n";
    print $OPERA_LG_CONFIG "lib_std=" . ($EDGE_ID_INFO[$edge_id] / 10) . "\n";
    #
    while(<FILE>){
	$str = $_;
	@line = split(/\t/, $str);
	#
	$c1 = $line[0];
	$c2 = $line[2];
	#
	$c1_strain = $contig_info{$c1}->{"STRAIN_ID"};
	$c2_strain = $contig_info{$c2}->{"STRAIN_ID"};

	next if(
	    ! (defined $c1_strain) || ! (defined $c2_strain) || 
	    $c1_strain eq "NA" || $c2_strain eq "NA" );
	
	#
	if($c1_strain eq $strain_id && $c2_strain eq $strain_id){
	    print OUT $str;
	}
	else{
	    #to rescue shared region in case of edge between contig from different strain only rescue for strain for lower coverage => higher strain ID
	    if($c1_strain * $c2_strain != 0 &&
	       ($c1_strain == $strain_id || $c2_strain == $strain_id) &&
	       ($c1_strain < $strain_id || $c2_strain < $strain_id)){
		print OUT $str;
		$shared_contig = $c1;
		$shared_contig = $c2 if($c1_strain == $strain_id);
		#$contig_info{$shared_contig}->{"SHARED_CONTIG"} = 1 if($edge_id == 0);#Only rescue local edges
	    }
	}
    }
    close(FILE);
    close(OUT);

    #Then filter rescue edges that gives rise to a local conflict
    
}

#Search for a mode for wich the negative banomial distribution conver a significant fraction of the genome studied
#If the largest contains seems to contains more than 1 genome:
#    * Try to deacrise the smoothing factor
#    * Give a warning indicating that it is not possible to perform strain analysis for that genome
sub select_mode{
    my ($mode_set, $assembly_length) = @_;
    for (my $i = @{$mode_set}-1; $i >= 0; $i--){
	
    }
}

sub compute_confidance_interval{
    my ( $strain_mean_cov, $dispersion_value) = @_;
    $R->set( 'mean', $strain_mean_cov );
    $R->set( 'dispersion', $dispersion_value);

    #my @interval = ()
    
    $a = $R->run(
	q ` s <- qnbinom(c(0.02), size=dispersion, mu=mean)`,
	q `print(s)`
	);
    @tmp = split(/\s+/, $a);
    $confidance_interval[0] = $tmp[1];
    
    $a = $R->run(
	q ` s <- qnbinom(c(0.98), size=dispersion, mu=mean)`,
	q `print(s)`
	);
    @tmp = split(/\s+/, $a);
    $confidance_interval[1] = $tmp[1];
    #return \@interval;

}

sub compute_mode{
    my ($window_distrib) = @_;
    
    $R->set( 'values', $window_distrib);
    $R->set( 'span', 11);
    
    $a = $R->run(
	## adpated from EDDA
	q `dens <- density(values)`,
	q `series <-dens$y`,
	q `z <- embed(series, span)`,
	q `s <- span%/%2`,
	q `ind <- apply(z, 1, which.max)`,
	q `v <- ind == (1 + s)`,
	q `result <- c(rep(FALSE, s), v)`,
	q `result <- result[1:(length(result) - s)]`,
	q `print(dens$x[result])`,
	);

    @tmp = split(/\s+/, $a);

    print STDERR " *** $a\n";

    my @res;
    @res = @tmp[1..@tmp-1]; #($tmp[1], $tmp[2]);
    @res = @tmp[2..@tmp-1] if(index($tmp[1], "[") != -1); #($tmp[2], $tmp[3]) if($tmp[1] eq "[1]");
    
    return \@res;
    
}



sub compute_probability{
    my ( $strain_mean_cov, $dispersion_value, $contig_mean_cov) = @_;
    $value = int($contig_mean_cov);
    #
    $R->set( 'mean', $strain_mean_cov );
    $R->set( 'dispersion', $dispersion_value);
    $R->set( 'k', $value);
    my $out1 = $R->run(
	q ` s <- dispersion * log(dispersion / (dispersion + mean)) + lgamma(dispersion + k) + k * log(mean / (dispersion + mean)) - lgamma(k + 1) - lgamma(dispersion)`,
	#  q`a <- $val`,
	q `print(s)`
	);

    print $out1 ."\n";
    
#return dispersion * log(dispersion / (dispersion + mean)) + //Compute once
#	lgammal(dispersion + k) + //Sum of the 2 sons
    #		k * log(mean / (dispersion + mean)) - //k * compute once
#		lgamma(k + 1) -	//Sum of the 2 sons
#		lgamma(dispersion); //Compute once globaly

}


sub estimate_mean{
    my ($mode, $dispersion) = @_;
    print STDERR " estimate_mean $mode $dispersion\n";
    return $mode * ($dispersion / ($dispersion -1));
}

sub filter_mapping{

    #my ($mapping_file);

    my $contig_mapping = "$species_dir/contig.map";
    
    #Mapping to the reference genome
    if(! -e $contig_mapping){
	my @tmp = split(/\//,$species_dir);
	my $species_name = $tmp[-1];
	my $reference = `grep $species_name $species_dir/../reference_length.dat | cut -f4`;chop $reference;

	run_exe("nucmer -p $species_dir/out $reference $species_dir/contigs.fa");
	run_exe("show-coords -lrcT $species_dir/out.delta > $species_dir/contig.map");
    }
    
    open(NUC_MAPPING, "sort -k1,1 -n $contig_mapping | ")
	or die "Parsing problem during read rescue using NUCMER mapping.\n";
    
    #skip the first four lines of the cluster-vs-cluster.txt file.
    <NUC_MAPPING>;
    <NUC_MAPPING>;
    <NUC_MAPPING>;
    <NUC_MAPPING>;
    
    my ($contig, $percent_mapped, $length, $start, $end);

    my $prev_contig = -1;
    my $prev_start = -1;
    my $prev_end = -1;
    my $prev_length = -1;
    #my $prev_percent_map = -1;

    open(OUT, ">$species_dir/filtered_contig.dat");
    
    while(<NUC_MAPPING>){
	if ($_ eq ""){
	    next;
	}
	#print STDERR $_;
	chop $_;
	my @line = split(/\t/, $_);
	$contig = $line[12];
	$percent_mapped = $line[10];
	$length = $line[8];
	$map_length = $line[5];
	$start = $line[0];$end = $line[1];
	#

	next if($map_length < 400 || $percent_mapped < 20);
	
	#
	if(($prev_start <= $start && $end <= $prev_end) ||#current alignement is incuded the previous alignement
	   ($start <= $prev_start && $prev_end <= $end)#previous alignement incuded the current alignement
	    ){
	    if($contig_info{$contig}->{"STRAIN_ID"} eq $contig_info{$prev_contig}->{"STRAIN_ID"} ){
		$filter_contig = $contig;
		if($prev_length < $length){
		    $filter_contig = $prev_contig;
		}
		print OUT $filter_contig .  "\t" . $contig_info{$filter_contig}->{"LENGTH"} . "\t" . $contig_info{$filter_contig}->{"STRAIN_ID"} . "\t" . 
		    $contig . "\t" . $start . "\t" . $end . "\t" .
		    $prev_contig . "\t" . $prev_start . "\t" . $prev_end . "\n";#<STDIN>;
		$contig_info{$filter_contig}->{"STRAIN_ID"} = "NA";
	    }
	}

	#Update the prev values
	$prev_contig = $contig;
	$prev_length = $length;
	$prev_start = $start;
	$prev_end = $end;
	
    }

    close(OUT);
    
}


    
sub run_exe{
    my ($exe) = @_;
    $run = 1;
    print STDERR "\n".$exe."\n";#<STDIN>;
    print STDERR `$exe` if($run);
}
