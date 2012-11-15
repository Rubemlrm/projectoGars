#!/usr/bin/perl
rename("/etc/apache2/ports.conf","/tmp/ports.conf.bak");
open(FILE,"<","/tmp/ports.conf.bak") or die("error reading file.");
open(OUTFILE,">","/etc/apache2/ports.conf") or die("error");
while(<FILE>){
        my $line=$_;
        chomp($line); #removes \n from line.
        if($line =~ /^Listen/){
                print OUTFILE "Listen teste";
        }else{
                print OUTFILE "$line\n";
        }
}
close(FILE);
close(OUTFILE);
#unlink("/");
exit;
