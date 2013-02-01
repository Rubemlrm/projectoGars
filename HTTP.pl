#!/usr/bin/perl
use warnings;
use strict;
use File::Basename; #modulo para verificar os caminhos dos ficheiros
use File::Copy qw(move);
use LWP; # módulo para simular um broweser
use WWW::Mechanize; # módulo que funciona sobre o módulo anterior de forma a adicionar mais funções ao móduo
#Global vars
my $apache2 = "/etc/apache2/apache2.conf";
my $apache2bak = "temp/apache2.conf.bak";
my $ports = "/etc/apache2/ports.conf";
my $portsbak= "temp/ports.conf.bak";
my $default_vhost = "/etc/apache2/sites-available/default";
my $default_vhostbk = "temp/000-default.bak";

&main();

sub main(){
  my $uid = `id -u`;
  #validação de permissões do utilizador
  if($uid != 0){
    print "ERRO:Não pode executar este script senão tiver permissões de root!\n";
    exit(1);
  }
  #verifica se o serviço está instalado
  system("dpkg -s apache2 >null 2>1");
    if($? == 1){ #caso seja igual a 1 dá erro
    print "Não tem o serviçco instalado no seu computador!\nDeseja instalar o servico no seu computador?(S/N)\n";
    chomp(my $opt = <STDIN>);
    if($opt eq "S" || $opt eq "s"){
        print "A executar instalacao do servico....\n";
        system("apt-get install -y apache2"); #instala o serviço
        if($? != 0){
            print "ERRO: Ocorreu um erro ao tentar instalar o serviço!\n";
            print "Detalhes: $!"; #caso de erro mostra uma mensagem de rro
            exit(1);
        }else{
            print "Instalacao do servico concluida com sucesso!\n";
          }
    }elsif($opt eq "N" || $opt eq "n"){
        print "O programa ira encerrar!\n ";
        exit(1);
    }else{
        print "ERRO: A opccao que escolheu e invalida!\n";
        exit(1);
      }
    }

    if((@ARGV == 0 || $ARGV[0] !~ /^-(h|p|t|f|c|l|n)$/ || $ARGV[0] !~ /^(start|restart|stop)/)){
        die("parametros invalidos". Execute ./HTTP -h para ajuda");
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
            if($ARGV[2] ne "-c"){
                print "ERRO: Tem que especificar um campo de pesquisa! \n";
                exit(1);
            }else{
                &saveClients($ARGV[1], $ARGV[3]);
            }
        }elsif($ARGV[0] eq "-h"){
            system("more docs/http.txt");
        }elsif($ARGV[0] =~ /(restart|stop|start)/){
            my $flag = `service apache2 $ARGV[0]`;
            if($? == 0){
                print "O comando $ARGV[0] foi executado com sucesso!\n";
            }else{
                print "Ocorreu um erro a executar o comando $ARGV[0]!\n";
            }
        }
    }else{
           print "Numero de parametros invalido.Execute .HTTP.pl -h para ver a sintax a ser usada\n";
    }
}

#Função responsável pela Alterteracao dos dados nos ficheiros de configuração 
#@param $_[0] ficheiro de origem
#@param $_[1] ficheiro Final 
#@param $_[2] valor a ser alterado
#@param $_[3] padrão de pesquisa
#
sub fileHandler($$$$$){
    my $origin_file=$_[0];
    my $new_file=$_[1];
    my $value = $_[2];
    my $search_pattern =$_[3];
    my $pattern_values = $_[4];
    system("touch $new_file");
    move($origin_file,$new_file);
    open(FILE,"<",$new_file) || die $!;
    open(NEW_FILE,">",$origin_file) || die $!;
    while(<FILE>){
        chomp(my $line=$_);
        if($line eq "$search_pattern $value"){
            print "AVISO:configuração já existente no ficheiro $new_file \n A verificar os restantes campos!\n";
            print NEW_FILE "$line\n";
        }elsif($line =~ /^$search_pattern/){
            print NEW_FILE "$pattern_values\n";
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
        #validação de portos , de forma a não serem usados portos reservados
    #}elsif($port =~ /(0|1|7|11|20|21|22|23|25|53|67|68|69)/){
    #    print("Erro:Escolheu uma porta reservada!\n");
    }else{        
        fileHandler($port,$portsbak,$port,"Listen","Listen $port");
        fileHandler($port,$portsbak,$port,"NameVirtualHost.\*\:","NameVirtualHost *:$port");
        fileHandler($default_vhost,$default_vhostbk,$port,"<VirtualHost.\*\:","<VirtualHost *:$port>");
        my $flag = `service apache2 restart`;
        if($? == 0){ #verifica se o ultimo comando foi efectuado com sucesso
            &verifyPort($port);
            print "Alteração efectuada com sucesso\n";
        }else{
            print "Existem erros na configuração como tal não foi possivel iniciar o Apache\n";
        }
    }
}
#funcao para alterar o timeout do apache2build-essential
sub changeTimeout($){
    chomp(my $timeout = $_[0]);
    if($timeout < 0 || $timeout > 9999){ #limita a escolha de timouts
        print("Valor de Timeout inválido\n");
        exit(1);
    }else{
        fileHandler($apache2,$apache2bak,$timeout,"Timeout","Timeout $timeout ");
        my $flag = `service apache2 restart`;
        if($? == 0){ #verifica se o ultimo comando foi efectuado com sucesso
            print "Alteração efectuada com sucesso\n";
        }else{
            print "Existem erros na configuração como tal não foi possivel iniciar o Apache!\n";
        }
    }
}

#funcçao para definir ficheiro de registo de erros
sub errorLog($){
    chomp(my $errorlog = $_[0]);
    if($errorlog !~ /\w+\.log$/){ #verifica se o nome do ficheiro é correcto
        print("Nome de ficheiro inválido.A extensão do ficheiro tem que ser .log\n");
        exit(1);
    }else{
        if(-e $errorlog){ #verifica se ficheiro já existe
            print "Ficheiro já existe";
            exit(1);
        }else{
            my $dirname =  dirname($errorlog); #verifica a directoria do ficheiro de log
            if(!$dirname){
                print "Directoria onde pretende guardar o ficheiro não existe\n, o ficheiro irá ser guardado na directoria ~/bin/logs\n";
                exit(1);
            }else{
                fileHandler($apache2,$apache2bak,$errorlog,"ErrorLog","ErrorLog $errorlog");
                my $flag = `service apache2 restart`;
                if($? == 0){ #verifica se ultimo comando foi efectuado com sucesso
                    print "Alteração efectuada com sucesso \n";
                }else{
                    print "Existem erros na configuração , como tal não foi possivel iniciar o Apache!\n";
                }
            }
        }
    }
}

#LogLevel()
#Funcao que vai especificar o nivel de logs que pertenbuild-essentialdemos
#@param $level tipo de nivel de logging

sub logLevel($){
    chomp(my $level = $_[0]);

    #verifica se o nivel de log é valido
    if($level !~ /(warn|debug|info|notice|error|crit|alert|emerg)/){
        print("Parametro de logging inválido\n ");
        exit(1);
    }else{
        fileHandler($apache2,$apache2bak,$level,"LogLevel","LogLevel $level");
        my $flag = `service apache2 restart`;
        if($? == 0){
            print "Alteração realizada com sucesso\n ";
        }else{
            print "Existem erros na configuração , como tal não pode ser executado o Apache!\n";
        }
    }
}

#saveClients()
#Funcao que irá guardar todos os dados dos clientes
sub saveClients($$){
    chomp(my $logfile = $_[0]);
    chomp(my $search = $_[1]);
    open(OUTFILE,">",$logfile) or die("error");
    my $string = `cat /var/log/apache2/access.log | grep $search | tr ' ' "#" | cut -f1,13,14,15 -d#`;
    if($string){
            $string =~ tr/#/ /;
            print OUTFILE ("$string\n");
    }else{
        print "Não foi encontrado nenhum resultado para esse valor de pesquisa!\n";
        exit(1);
    }
    close(OUTFILE);
}

sub verifyPort($){
    my $port = $_[0];
    #inicia um objecto que irá funcionar como brower
    my $mech = WWW::Mechanize->new();
    my $url = "http://localhost:$port";
    my $response = $mech->get($url); # irá verifcar se o link tem resposta ou não
    if(!$response->is_success){ # caso não tenha sucesso dá erro!
        print "ERRO:Existe um erro na configuração e não é possivel aceder ao servidor apache pela porta $port !\n";
        exit(1);
    }else{
        print "Configuração testada com sucesso, para aceder ao servidor apache use o seguinte url
        http://localhost:$port !\n";
    }
}
