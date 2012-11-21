#!/usr/bin/perl
use warnings;
use strict;


#Global vars
my $apache2 = "/etc/apache2/apache2.conf";
my $apache2bak = "/tmp/apache2.conf.bak";
my $ports = "/etc/apache2/ports.conf";
my $portsbak= "/tmp/ports.conf.bak";


if((@ARGV == 0 || $ARGV[0] !~ /^-(h|p|t|f|c|l|n)$/ && $ARGV[0] !~ /^(start|restart|stop)/)){
    die("parametros inválidos");
}elsif(!(@ARGV < 2 || @ARGV > 4)){
    if($ARGV[0] eq "-p"){
        &changePort($ARGV[1]);
    }elsif($ARGV[0] eq "-t"){
        &changeTimeout($ARGV[1]);
    }elsif($ARGV[0] eq "-n"){
        &logLevel($ARGV[1]);
    }elsif($ARGV[0] eq "-l"){
        &errorLog($ARGV[1]);
    }elsif($ARGV[0] eq "-f"){
        &saveClients($ARGV[1]);
    }elsif($ARGV[0] =~ /(restart|stop|start)/){
        &actions($ARGV[0]);
    }
}else{
       print "Número de parametros inválido.Execute .HTTP.pl -h para ver a sintax a ser usada\n";
}


#Função responsável pela Alteração de dados nos ficheiros de configuração 
#@param $_[0] ficheiro de origem
#@param $_[1] ficheiro Final 
#@param $_[2] valor a ser alterado
#@param $_[3] padrão de pesquisa
#
sub fileHandler($$$$){
    my $origin_file=$_[0];
    my $new_file=$_[1];
    my $value = $_[2];
    my $search_pattern =$_[3];
    print $search_pattern;
    rename($origin_file,$new_file);
    open(FILE,"<",$new_file) || die $!;
    open(NEW_FILE,">",$origin_file) || die $!;
    while(<FILE>){
        chomp(my $line=$_);
        if($line eq "$search_pattern $value"){
            print "ERRO:configuração já existente no ficheiro de config\n ";
            print NEW_FILE "$line\n";
        }elsif($line =~ /^$search_pattern/){
            print NEW_FILE "$search_pattern $value\n";
        }else{
	    print NEW_FILE "$line\n";
   		}
	 }

    close(FILE);
    close(NEW_FILE);
    unlink($new_file);
}

#Funcao para alteração de porta do apache
sub changePort($) {
    chomp(my $port = $_[0]);
    if($port < 0 || $port > 65000){
        print("Valor do porto inválido\n");
        exit(1);
    }else{
        fileHandler($ports,$portsbak,$port,"Listen");
	fileHandler($ports,$portsbak,$port,"NameVirtualHost\ \*\:");
        print "Alteração efectuada com sucesso\n";
    }
}

#funcao para alterar o timeout do apache2
sub changeTimeout($){
    chomp(my $timeout = $_[0]);
    if($timeout < 0 || $timeout > 99999){
        print("Valor de Timeout inválido\n");
        exit(1);
    }else{
        fileHandler($apache2,$apache2bak,$timeout,"Timeout");
        print "Alteração efectuada com sucesso\n";
    }
}

#funcao de pesquisa
sub search($) {
    #body ...
}

#funcçao para definir ficheiro de registo de erros
sub errorLog($){
    chomp(my $errorlog = $_[0]);
    if($errorlog !~ /\w+\.log$/){
        print("Nome de ficheiro inválido.A extensão do ficheiro tem que ser .log");
        exit(1);
    }else{
        fileHandler($apache2,$apache2bak,$errorlog,"ErrorLog");
        print "Alteração efectuada com sucesso \n";
    }


}

#LogLevel()
#Funcao que vai especificar o nivel de logs que pertendemos
#@param $level tipo de nivel de logging

sub logLevel($){
    chomp(my $level = $_[0]);
    if($level !~ /(warn|debug|info|notice|error|crit|alert|emerg)/){
        print("Parametro de logging inválido\n ");
        exit(1);
    }else{
        fileHandler($apache2,$apache2bak,$level,"LogLevel");
        print "Alteração realizada com sucesso\n ";
    }
}

##TO-DO List 
#funcao para pesquisar nome ou ip no ficheiro
#adicionar funçao para adicionar basename caso não seja fornecido
#corrigir função de logs
#adicionar função de ajuda
#adicionar função para verificar se o utilizador tem privilegios administrativos ou não.

