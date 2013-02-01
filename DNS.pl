#!/usr/bin/perl
use warnings;
use strict;
use Data::Validate::IP qw(is_ipv4 is_ipv6); #modulo para validar os ip
use Data::Validate::Domain qw(is_domain); #modulo para validar os dominios
my $bind = "/etc/bind/named.conf.local";
my $tmpbind = "/tmp/bind.bk";

&main();

sub main(){
    my $uid = `id -u`;
    #validacao de permissoes de utilizador
    if($uid != 0){
        print "ERRO: Nao pode executar este script se nao tiver permissoes root!\n";
        exit(1);
    }

     #validacao se o serviço está instalado
    my $flag = `ls /etc/init.d | grep bind9`;
    if(!($flag)){ #verica o output do ultimo comando se for igual a 1 dá erro
    print "Nao tem o serviço instalado no seu computador!\nDeseja instalar o serviço no seu computador?(S/N)\n";
    chomp(my $opt = <STDIN>);
    if($opt eq "S" || $opt eq "s"){
        print "A executar instalacao do servico....\n";
        system("apt-get install -y bind9"); #inicia a instalação do serviço
        if($? != 0){  #verifica o output do ultimo comando se for maior que 0 dá erro
            print "ERRO: Ocorreu um erro ao tentar instalar o servico!\n";
            print "Detalhes: $!"; #messagem de erro!
            exit(1);
        }else{
            print "Instalaco do serviço concluida com sucesso!\n";
          }
    }elsif($opt eq "N" || $opt eq "n"){
        print "O programa ira encerrar!\n ";
        exit(1);
    }else{
        print "ERRO: A opccao que escolheu é invalida!\n";
        exit(1);
      }
    }
    
    #valida o numero de argumentos passados e se as opcoes estao correctas
    if((@ARGV == 0 || $ARGV[0] !~ /^-(h|a|r|f|e|d|v)$/ && $ARGV[0] !~ /^(start|restart|stop)/)){
        die("ERRO:Parametros invalidos\n");

    }elsif(!(@ARGV > 5)){
        if($ARGV[0] eq "-a"){
          if($ARGV[1] ne "-f" && !($ARGV[2])){

            &addDomain($ARGV[1],0);
          }elsif($ARGV[1] ne "-f" && $ARGV[2] ne ""){
            &addDomain($ARGV[1],$ARGV[1]);
          }else{
            &addSeveralDomains($ARGV[2]);
          }
        }elsif($ARGV[0] eq "-r"){
            &delDomain($ARGV[1]);
        }elsif($ARGV[0] eq "-e"){
            if(@ARGV != 5){
                print "ERRO: Numero de parametros invalidos! Execute ./DNS -h para verificar qual é a sintaxe
                correcta!\n";
                exit(1);
            }else{
                &addDomainEntry($ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4]);
            }
        }elsif($ARGV[0] eq "-d"){
            if(@ARGV != 3){
                print "ERRO: Numero de parametros invalidos!Execute ./DNS -h para verificar a sintaxe correcta!\n";
                exit(1);
            }else{
                &delDomainEntry($ARGV[1],$ARGV[2]);
            }
        }elsif($ARGV[0] eq "-v"){
            if(@ARGV == 3){
                &testDomain($ARGV[1],$ARGV[2],$ARGV[3]);
            }else{
                print "Numero de parametros invalido!Execute ./DNS -h para vericar a sintaxe correcta!\n";
                exit(1);
            }
        }elsif($ARGV[0] =~ /(restart|stop|start)/){
            system("service bind9 $ARGV[0]");
        }else{
            system("more docs/dns.txt");
        }
    }else{
        print "Numero de parametros invalido.Execute ./NFS.pl -h para ver a sintax a ser usada.\n";        
    }
}


##### Funções de gestão de ADD/REM dominios

sub addDomain($$){
    my $domain = $_[0];
    my $ip = $_[1];
    my $tmp;

    my $grep = `grep "$domain" /etc/bind/named.conf.local`;
    if($grep){
        print "ERRO: Ja existem configuracoes para esse dominio!\n";
        exit(1);
    }

    if(-e "/etc/bind/db.$domain"){
        print "ERRO: Ja existe o ficheiro db. respectivo a esse dominio\n";
        exit(1);
    }

    print "A validar dominio.....\n";
    if(!is_domain($domain)){ #verifica se é um dominio válido
        print "ERRO:Dominio invalido!\n";
        exit(1);
    }else{
        print "OK\n";
    }

    print "A validar IP .....\n";
    if(!($ip)){
        print "Aviso:Nao foi dado nenhum IP, a usar o ip 127.0.0.1 por defeito!\n";
        $ip = "127.0.0.1";
    }
    if(!(is_ipv4($ip)) || $ip ne "127.0.0.1"){ #verifica se é um ipv4 válido
        print "ERRO:IP inserido e invalido\n";
    }

    print "A validar existencia de ficheiro db......";
    if(-e "/etc/bind/db.$domain"){ #verifica se ficheiro já existe
        print "ERRO: Ja existe um ficheiro de configuracao para esse dominio\n";
        exit(1);
    }else{
        print "Sucesso\n";
    }

    print "A verificar se informacao relativa ao dominio $domain ja existe....\n";
    open(FILE,"<","$bind") || die $!;
    my @file = <FILE>;
    close(FILE);
    my @tmp = `grep "//zone $domain" $bind`; #verifica se entrada de dominio já existe no ficheiro de config
    $tmp = @tmp;
    if($tmp != 0){
	    print "ERRO: Dominio ja existe!\n";
	    exit(1);
    }else{
        print "Não existe informacao relativa ao dominio! A iniciar processo de criacao...\n";
	    &domainFilesCreator($domain,$ip);
    }
}

sub delDomain($){
  my $domain = $_[0];
  my $flag;
  my ($cont,$posy,$posx,$dumbVar,$ip) =  0;
  my @tmp;
  open(FILE,"/etc/bind/named.conf.local") || die $!;
  my @file = <FILE>;
  close(FILE);
  if((grep("//zone $domain",@file))){ #verifica se existe a ocurrencia //zone $domain no ficheiro , caso exista executa o processo de eliminação de entrada
    foreach my $line(@file){
      chomp($line);
      if($line eq "//zone $domain"){
        $posx = $cont; #contador que vai guardar a posição do array onde a configuração do dominio começa
      }elsif($line eq "//endzone $domain"){
        $posy = $cont +1 ; #contador que vai guarda a posição final do array onde a configuração do dominio acaba
      }else{
        $dumbVar = $cont;  #variavel nula
      }
      $cont++;
    }
    @tmp = splice(@file,$posx,$posy); #criar um novo array sem as configurações do dominio pretendido
    if(@tmp != 0){ #verifica se o array não está fazio
        open (NEW_FILE,'>',"/etc/bind/named.conf.local") || die $!;
        foreach(@file){
            print NEW_FILE $_."\n";
    
        }
    }

    unlink("/etc/bind/db.$domain") || die $!; # apaga o ficheiro de configuração do dominio pretendido
    print "Configuracao relativa ao dominio $domain foi eliminada!\n ";
    system("service bind9 restart");
  }else{
     print "ERRO: Nao existe nenhuma informacao relativa a esse dominio!\n";
     exit(1);
  }
}

sub addSeveralDomains($){
	my $file = $_[0];
    print "A ler ficheiro de dominios....\n";
    #abre ficheiro com os dominios
	open(FILE,"$file") || die $!;
	my @file = <FILE>;
	close(FILE) || die $!;
    print "Ficheiro lido com sucesso!\n";

    #abre o ficheiro named.conf.local
	open(BIND,"<",$bind) || die $!;
    my @bind = <BIND>;
    close(BIND) || die $!;
    
    print "A iniciar processo de criacao de dominio...\n";
    #percorre o array dos dominios e verifica se ja existe o dominio!
	foreach my $line (@file){
        chomp($line);
		my @temp = split /;/, $line;
		chomp(@temp);
        my $domain = $temp[0];
        my $ip = $temp[1];
        my $grep = `grep "zone $domain" /etc/bind/named.conf.local`;
            if($grep ne ""){
                print "Aviso: Dominio \" $domain \" já existe!\n";
            }elsif(-e "/etc/bind/db.$domain"){
                print "ERRO:FIcheiro de configuracao  do $domain ja existe!\n";
            }else{
                if(!(is_domain($domain))){
                    print "ERRO: Dominio $domain invalido!\n";
                    exit(1);
                }elsif(!(is_ipv4($ip)) && $ip ne "127.0.0.1"){
                    print "ERRO: $ip inválido!\n";
                }else{
				    &domainFilesCreator($domain,$ip);
                    print "Sucesso: Foram criadas as configuracoes necessárias para o dominio $domain e seu respectivo ip $ip !\n";
			    }
            }
    }
    system("service bind9 restart");
}

sub domainFilesCreator($$){
	my $domain = $_[0];
    my $ip = $_[1];

    #####Informação que vai ser introduzida no ficheiro Named.conf.local
	open(NEW_FILE,'>>',"$bind") || die $!;
    print NEW_FILE "//zone $domain\n";
    print NEW_FILE "zone \"$domain\" {\n";
    print NEW_FILE "\ttype master\n";
    print NEW_FILE "\tfile \"/etc/bind/db.$domain\";\n";
    print NEW_FILE "};\n";
	print NEW_FILE "//endzone $domain\n";
    close(NEW_FILE) || die $!;

    #criação dos ficheiros de configuracao
    if(-e "/etc/bind/db.$domain"){
        print "ERRO: Ficheiro bd.$domain já existe!\n";
        exit(1);
    }else{
        open(FILE,'>',"/etc/bind/db.$domain") || die$!;
        my $date = `date +%Y%m%d`;
        chomp($date);
        $date = $date."1";

        #informação que vai ser introduzida no ficheiro db.*
        print FILE "\$TTL\t60480";
        print FILE "\@\tIN\tSOA\t$domain. webmaster\@$domain.(\n";
        print FILE "\t\t\t$date\n\t\t\t604800\n\t\t\t86400\n";
        print FILE "\t\t\t2419200\n\t\t\t86400 )\n;\n";
        print FILE "\@\tIN\tNS\t$domain.\n";
        print FILE "\@\tIN\tA\t$ip\n";
        print FILE "\@\tIN\tAAAA\t ::1\n";
        close(FILE) || die $!;
        
    }
}

sub addDomainEntry($$$){
    my $domain = $_[0];
    my $resourceRecords = $_[1];
    my $resourceValue = $_[2];
    my $host = $_[3];
    

    if(-e "/etc/bind/db.$domain"){

        #validação do tipo de resource record
        if($resourceRecords !~ /^(A|NS|PTR|MX|CNAME|TXT|HINFO)/){
            print "ERRO: Resource Record invalido!\n";
            exit(1);
        }

        #validação do nome utilizado para o resource value
        if($resourceValue !~ /^[a-z0-9-]/i){
            print "ERRO: Nome invalido para o Resource Record!\n";
            exit(1);
        }

        #validação do host para saber se é um IP válido ou um dominio válido
        if(!(is_ipv4($host) || is_domain($host))){
            print "ERRO: Host invalido!\n";
            exit(1);
        }

        #verifica se existe o resource record no ficheiro
        my $grep = `grep "^$resourceValue" /etc/bind/db.$domain`;
        if($grep){
            print"ERRO: Ja existe esta informaçao no ficheiro de configuração do dominio $domain!\n";
            exit(1);
        }else{
            open(FILE,">>","/etc/bind/db.$domain") || die $!;
            print FILE "$resourceValue\t\tIN\t\t$resourceRecords\t\t$host\n";
            close(FILE) || die $!;
            print "Adicionar informacao ao ficheiro de configuracao do dominio $domain com sucesso!\n";
            system("service bind9 restart");
        }

    }else{
        print "ERRO: Nao existe nenhum ficheiro de configuracao para o dominio $domain !\n";
        exit(1);
    }
}

sub delDomainEntry($$){
    my $domain = $_[0];
    my $recordValue = $_[1];
    
    print "A verificar existencia do ficheiro db.$domain....\n";

    #verifica se existe o ficheiro de db.* 
    if(-e "/etc/bind/db.$domain"){
        print "Ficheiro existe!\nA verificar dados do ficheiro......\n";
        
        #verifica se existe o recordValue que queremos apagar e caso exista devolve o número da linha
        my $grep = `grep -n "^$recordValue" /etc/bind/db.$domain | cut -d ":" -f1`;
        if($grep){
            print "Ocurrencia encontrada ! A efectuar operacao de remocao!\n";
            open(FILE,"<","/etc/bind/db.$domain") || die $!;
            my @file = <FILE>;
            close(FILE);
            #remove do array o index corresponde ao recordValue que queremos apagar
            delete $file[$grep-1];
            open(BIND,">","/etc/bind/db.$domain") || die $!;
            foreach my $line (@file){
                print BIND "$line";
            }
            close(BIND) || die $!;
            print "Entrada do ficheiro db.$domain removida com sucesso!\n";
            system("service bind9 restart");
        }else{
            print "ERRO: Nao foi encontrada nenhuma ocurrencia no ficheiro db.$domain !\n";
            exit(1);
        }
    }else{
        print "ERRO nao existe nenhum ficheiro de configuraçao para o dominio $domain !\n";
        exit(1);
    }
}

sub testDomain($$){
    my $domain = $_[0];
    my $domainconf = $_[1];
    
    #verifica se o dominio passado é válido
    if(!(is_domain($domain))){
        print "Dominio inválido!\n";
    }
    
    #verifica se o ficheiro de config do dominio existe
    if(-e "$domainconf"){
        print "A verificar configuraçoes para o dominio $domain ...\n"; 
        system("named-checkzone $domain /etc/bind/db.$domainconf");
    }else{
        print "ERRO:Nao existe nenhum ficheiro de configuracao relativo ao dominio $domain !\n";
        exit(1);
    }

}
