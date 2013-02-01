#!/usr/bin/perl
use warnings;
use strict;
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use Data::Validate::Domain qw(is_domain);
#Global Vars
my $nfsconf = "/etc/exports";

&main();

sub main(){
  my $uid = `id -u`;

  #validação de permissões do utilizador
  if($uid != 0){
    print "ERRO:Nao pode executar este script senao tiver permissoes de root!\n";
    exit(1);
  }
  #validação se o serviço está instalado
  my $flag = `ls /etc/init.d | grep "nfs-kernel-service"`;
  if(!($flag)){
      print "Não tem o serviçco instalado no seu computador!\nDeseja instalar o servico  no seu computador?(S/N)\n";
      chomp(my $opt = <STDIN>);
      if($opt eq "S" || $opt eq "s"){
          print "A executar instalacao do servico....\n";
          system("apt-get install -y nfs-kernel-server"); #instala o serviço
          if($? != 0){ # verifca se deu erro
              print "ERRO: Ocorreu um erro ao tentar instalar o servico!\n";
              print "Detalhes: $!"; # mostra mensagem de erro
              exit(1);
          }else{
              print "Instalacao do servico concluida com sucesso!\n\n";
          }
      }elsif($opt eq "N" || $opt eq "n"){
          print "O programa ira encerrar!\n ";
          exit(1);
      }else{
          print "ERRO: A opcao que escolheu e invalida!\n";
          exit(1);
      }
  }

  #validação dos argumentos passados
  if((@ARGV == 0 || $ARGV[0] !~ /^-(l|t|a|d|h)$/ && $ARGV[0] !~ /^(start|restart|stop)/)){
      print("ERRO:Parametros invaidos. Execute sudo ./NFS -h para ajuda");
      exit(1);
  }elsif(!(@ARGV < 1)){
    if($ARGV[0] eq "-l"){
      &listNFS();
    }elsif($ARGV[0] eq "-t"){
      if(!($ARGV[1])){
	print "ERRO: Devera especificar uma das opcoes extra. Execute ./NFS.pl -h para ajuda\n";
      }else{
      	&showstats($ARGV[1]);
      }
    }elsif($ARGV[0] eq "-a"){
      if(!($ARGV[2])){
	print "ERRO: Devera especificar uma directoria!\n";
      }else{      
	shift(@ARGV);
      	&addExport(\@ARGV);
      }
    }elsif($ARGV[0] eq "-d"){
      if(!($ARGV[1])){
	print "ERRO: Deve especificar a directoria que pretende remover\n";
	exit(1);
      }else{
      	&removeExport($ARGV[1]);
      }
    }elsif($ARGV[0] =~ /(restart|stop|start)/){
      system("service nfs-kernel-server $ARGV[0]");
    }else{
      system("more docs/nfs.txt");
    }
  }else{
    print "Numero de parametros invalido.Execute ./NFS.pl -h para ver a sintax a ser usada.\n";
  }
}


#Funcao ue lista todas as pastas que o NFS esta a partilhar
sub listNFS(){
    my $list = `cat /etc/exports | grep "^/"|tr " " "#"|cut -f1 -d#`;
    if(!($list)){
	print "O servidor de NFS nao esta a partilhar nenhuma directoria!\n";
    }else{	
    print "O servidor de NFS esta a partilhar as seguintes directorias.\n";
    print $list;
    print "Fim da listagem.\n";
    }
}

#Funcao que remove uma exportacao
#var $_[0] => recebe um variavel que contem a directoria a ser eleminada

sub removeExport($){
  my $dir = $_[0];
  my $flag;
  my @file;
  my $cont = 0;
  open(FILE,"<",$nfsconf) || die $!;
  @file = <FILE>;
  close(FILE);
  chomp(@file);

  print "A verificar se partilha existe no ficheiro de exportacoes!\n";
  if(!($flag= grep(/^$dir/, @file))){ 
    print "ERRO: A partilha não existe no ficheiro de exportaçcoesn";
    exit(1);
  }else{
    print "AVISO: A partilha existe no ficheiro de exportacoes iniciar processo de remocao\n";
    foreach my $line(@file){
      chomp($line);
      if($line =~ /^$dir/){
        delete $file[$cont];
      }else{
        #elemina as linhas em branco do array
        if($line =~ /(^$)/){
          delete $file[$cont];
        }
      }
      $cont++;
    }
    open(FILE,">","/etc/exports") || die $!;
    foreach my $newfile(@file){
      print FILE "$newfile \n";
      }  
    close(FILE);
    print "Processo de remocao concluido!A reiniciar servico NFS!\n";
    system("service nfs-kernel-server restart");
  }
}

#Função que ira gerar a lista de novas exportações e adiciona-as ao ficheiro /etc/exports
#var $_[0] => recebe o array por referência com a lista de argumentos e valores passados para esta funcionalidade

sub addExport($){
  my $data = $_[0];
  my($dir, $hosts, $perm, $mods,$flag) = " ";
  my(@hosts,@mods,@perm);
  my %hashlist;
  if($data < 2 && $data !~ /(2|4|6)/){
      print "ERRO: Numero de paramentros inváalido!\n";
  }
 
  #verifica os dados passados e se são válidos
  if ($data == 2 && @$data[0] || $data == 4 && @$data[2] || $data == 6 && @$data[4] || $data == 8 && @$data[6] !~
      /^-(dir|n|p|k)$/){
      print "ERRO: Anomalia na passagem de parametros\n";
     exit(1);
  }

  #verifica e atribui o valor a variavel correspondente 
  if (@$data[0] =~ /-dir/) { 
    $dir = @$data[1]; 
  }elsif(@$data[0] =~ /-n/){ 
    $hosts = @$data[1];
  }elsif(@$data[0] =~ /-p/){
    $perm = @$data[1];
  }else{
    $mods = @$data[1];        
  }
        
  if(@$data[2] && @$data[3]){
    if (@$data[2] =~ /-dir/){ 
      $dir = @$data[3]; 
    }elsif(@$data[2] =~ /-n/){ 
      $hosts = @$data[3]; 
    }elsif(@$data[2] =~ /-p/){ 
      $perm = @$data[3]; 
    }else{
      $mods = @$data[3];
    }
  }

  if(@$data[4] && @$data[5]){
    if (@$data[4] =~ /-dir/){ 
      $dir = @$data[5]; 
    }elsif(@$data[4] =~ /-n/){ 
      $hosts = @$data[5]; 
    }elsif(@$data[4] =~ /-p/){ 
      $perm = @$data[5]; 
    }else{
      $mods = @$data[5];
    }
  }

  if(@$data[6] && @$data[7]){
    if (@$data[6] =~ /-dir/){ 
      $dir = @$data[7]; 
    }elsif(@$data[6] =~ /-n/){ 
      $hosts = @$data[7]; 
    }elsif(@$data[6] =~ /-p/){ 
      $perm = @$data[7]; 
    }else{
      $mods = @$data[7];
    }
  }

  #verifica se as variaveis tem algum valor , se tiverem é que faz o split
  if($perm){
    @perm = split(',',$perm);
  }
  if($hosts){
    @hosts = split(',',$hosts);  
  }
  if($mods){
    @mods = split(',', $mods);
  }
  
  #caso no passo anterior nenhuma variavel tivesse tido valor , neste passo vamos dá valores predefinidos aos arrays de forma a ser usados
  #na função generatelist 
  if(@perm == 0){
    push(@perm, 'ro');
  }
  if(@hosts == 0){
    push(@hosts, "*");
  }
  if(@mods == 0){
    push(@mods,'async');
  }
  %hashlist = &generateList(@hosts,@mods,@perm);


  #atribuição dos valores retornados pelas funções
  $dir = &Valdir($dir);
  print $dir;
  
  print "A iniciar actualizacoes do ficheiro de exportacoes\n";
  
  open(FILE,">>$nfsconf");
    print FILE "\n";
    my $cont = 0;  
    print FILE "$dir";
    for my $index (keys %hashlist){
      for my $info(sort values %{ $hashlist{$index} }){
        if($cont == 0){
          print FILE " $info(";
        }elsif($cont == 1){
          print FILE "$info,"
        }else{
          print FILE "$info)";
          }
        $cont++;
      }
      $cont = 0;
      
    }
  print "\n";
  close(FILE);
  print "Actualizacao do ficheiro de exportacoes concluida\n";
  system("service nfs-kernel-server restart");
}

#Função que irá validar se a directoria existe e realizar as opções necessárias
#var $_[0] => vai receber o valor da directoria que queremos adicionar aos exports

sub Valdir($){
  my $dir = $_[0];
  my $tmp_dir = $dir;
  my $choice;
  #verifica se foi especificado uma directoria
  print $dir;
  if(! -d $dir){
     print "ERRO: E obrigatorio specificar uma directoria!\n";
     exit(1);
  }

  #Verifica se partilha ja existe
  my $flag = `cat /etc/exports | grep "/^$dir$/`;
  print $flag;
  if($flag){
    print ("AVISO: Partilha ja existe\n");
    print "Pretende especificar outra directoria ?(S/N) \n";
    chomp($choice = <STDIN>);
    if($choice eq "S" || $choice eq "s"){
      print "Introduza a directoria que pretende usar:\n";
      chomp($tmp_dir = <STDIN>);
      &Valdir($tmp_dir);
    }else{
      print "ERRO: Devido a nao se poderem ter entrada duplicadas no ficheiro export e a sua escolha ter sido N o programa ira encerrar!\n";
      exit(1);
    }

  }

  #verificar se directoria existe , caso não existe apresta uma hipotese para cria-la
  if(!-d $dir){
    print "ERRO: Directoria nao existe. Pretende que a mesma seja criada?(S/N)\n";
    chomp($choice = <STDIN>);
    if($choice eq "S" || $choice eq "s"){
      mkdir $dir || die $!;
    }else{
      print "ERRO: Visto que  nao pretende que a directoria seja criada o script ira encerrar!\n";
      exit(1);
    }
  }
  #irá validar se existiu mudança no valor da variavel recebida , caso exista irá retornar o novo valor
  if($tmp_dir ne $dir){
    return $tmp_dir;
  }else{
    return $dir;
  }
}


#Esta função valida todos elementos dos arrays e executa as operações necessárias caso um valor seja inválido.
#var $_[0] => recebe um valor escalar com as permissões
#var $_[1] => recebe um valor escalar com os hosts
#var $_[2] => recebe um valor escalar com as permissões extra
#return %hashlist => retorna uma hash de hashes

sub generateList($$$){
  my @hosts = $_[0];
  my @mods = $_[1];
  my @perm = $_[2];
  my($perm_size,$hosts_size,$mods_size);
  my %hashlist;
  $perm_size = @perm;
  $hosts_size = @hosts;
  $mods_size = @mods;

  #Valida o tamanho dos diferentes arrays e caso os arrays @perm e @mods sejam inferiores ao array @hosts 
  #irá popula-los com definições pré-defenidas.Caso os arrays @perm e @mods seja superiores ao array @host
  #irá imprimir um erro

  if ($perm_size < $hosts_size){
    for (my $cont = $perm_size; $cont < $hosts_size; $cont++){
      push(@perm,'ro');
    }
  }elsif($perm_size > $hosts_size){
      print "ERRO: O numero de permissõoes nao deve ser superior ao númeumero  de hosts!\n";
      exit(1);
  }
    
  if($mods_size < $hosts_size){
    for (my $cont = $mods_size; $cont < $hosts_size; $cont++){
      push(@mods,'async');
    }
  }elsif($mods_size > $hosts_size){
     print "ERRO: O número de permissões não pode ser superior ao número de hosts!\n";
    exit(1);
  }else{
    print "Validacao do  numero de elementos das listagens terminadas.\n";
  }
  

  #Inicio da criação de uma Hash de hashes
  #Atribuição dos valores respectivos aos hosts
  my $cont = 0;
  foreach my $tmp_host (@hosts){
    &valHost($tmp_host);
    $hashlist{$cont}{'host'} = $tmp_host;
    $cont++;
  }
   
  #Atribuição dos valores respectivos as permissões
  $cont = 0;
  foreach my $tmp_perm (@perm){
    if($tmp_perm !~ /(ro|rw)/){  #verifca se a permissão é valudida
      printf "AVISO: Devido a permissão atribuida ao host $hashlist{$cont}{'host'} ser invalida este host ira ficar com
      permissoes de read-only\n";
      $hashlist{$cont}{'perm'} = 'ro';
      $cont++;
    }else{
        $hashlist{$cont}{'perm'} = $tmp_perm;
        $cont++;
    }
  }

  #Atribuição dos valores respectivos as parametros extra
  $cont = 0;
  foreach my $tmp_mod(@mods){ # verica se o modo é valido
    if($tmp_mod !~ /(no_root_squash|no_subtree_check|sync|async)/){
     printf "AVISO: Devido ao parametro extra atribuido ao host $hashlist{$cont}{'host'} ser invalida este host ira ficar com
     permissoes de async!\n";
     $hashlist{$cont}{'perm'} = 'ro';
     $cont++;
    }else{
      $hashlist{$cont}{'mod'} = $tmp_mod;
      $cont++;
    }
  }
  #retorna a hash de hashs para função generaList();
  return(%hashlist);
}

#Esta função irá validar se o valor da variavel é valido ou não
#var $_[0] => recebe a variavel com o valor do host
sub valHost($){
  my $host = $_[0]; 
  #verifica se o host é um ip v4,v6 ou um dominio
  if($host =~ /^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})/ || $host =~ /^([0-9a-fA-F]{4}|0)(\:([0-9a-fA-F]{4}|0)){7}$/){

    if(!is_ipv4($host) && !is_ipv6($host)){ #valida o ip
      print "ERRO: Endereco $host não segue as normas do IPv4 nem IPv6!\n";
      exit(1);
    }
  }elsif($host =~ /^((([a-z]|[0-9]|\-)+)\.)+([a-z])+$/i){
    if(!is_domain($host)){ #valida o dominio
        print "ERRO: Endereco $host invalido\n"; 
        exit(1);
    }     
  }elsif($host eq "*"){
    print "AVISO: Todos os dispositivos terão acesso a esta partilha\n";
  
  }else{
    print "ERRO: Informacao do host $host invalida\n";
    exit(1);
  }
}

#Função relativa as estatisticas do serviço
sub showstats($){
  my $param = $_[0];
  if($param !~ /^-(s|c|n|r|v|)/){
    print "ERRO: Parametro extra invalido, faça ./NFS.pl -h para ver todas as opçcoes disponiveis !\n";
    exit(1);
  }else{  
    if($param eq "-s"){
      print "Estatisticas relativas ao servidor NFS\n";
      system("nfsstat -s");
    }elsif($param eq "-c"){
      print "Estatisticas relativas aos clientes \n";
      system("nfsstat -c");
    }elsif($param eq "-n"){
      print "Estatisticas relativas ao serviço NFS vs 2/3/4 do mesmo\n";
      system ("nfsstat -n234");
    }elsif($param eq "-r"){
      print "Estatisticas relativas ao RPC do servico\n";
      system("nfsstat -r");
    }elsif($param eq "-v"){
      print "A imprimir todas as Estatisticas do servico \n";
      system("nfsstat -v");
    }else{
      print "Nao e possivel mostrar Estatisticas para o argumento passado\n";
    }
  }
}
