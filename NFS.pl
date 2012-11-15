#!/usr/bin/perl
use warnings;
use strict;
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use Data::Validate::Domain qw(is_domain);
use Data::Dumper;
#Global Vars
my $nfsconf = "/etc/exports";

&main();

sub main(){
  my $uid = `id -u`;
  #validação de permissões do utilizador
  if($uid != 0){
    print "ERRO:Não pode executar este script senão tiver permissões de root!\n";
    exit(1);
  }

  #validação dos argumentos passados
  if((@ARGV == 0 || $ARGV[0] !~ /^-(l|t|a|d|h)$/ && $ARGV[0] !~ /^(start|restart|stop)/)){
      die("ERRO:Parametros inválidos");
  }elsif(!(@ARGV < 1)){
    if($ARGV[0] eq "-l"){
      &listNFS();
    }elsif($ARGV[0] eq "-t"){
      &showstats($ARGV[1]);
    }elsif($ARGV[0] eq "-a"){
      shift(@ARGV);
      &addExport(\@ARGV);
    }elsif($ARGV[0] eq "-d"){
      &removeExport($ARGV[1]);
    }elsif($ARGV[0] =~ /(restart|stop|start)/){
      system("/etc/init.d/nfs $ARGV[0]");
    }else{
      system("more nfs.txt");
    }
  }else{
    print "Número de parametros inválido.Execute ./NFS.pl -h para ver a sintax a ser usada.\n";
  }
}


#Função que lista todas as pastas que o NFS está a partilhar
sub	listNFS(){
	my $list = `cat /etc/exports | grep "^/"|tr " " "#"|cut -f1 -d#`;
	print "O servidor de NFS está a partilhar as seguintes directorias.\n";
  print $list;
  print "Fim da listagem.\n";
}

#Função que remove uma exportação
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

  print "A verificar se partilha existe no ficheiro de exportações!\n";
  if(!($flag= grep(/^$dir/, @file))){
    print "ERRO: A partilha não existe no ficheiro de exportações!\n";
    exit(1);
  }else{
    print "AVISO: A partilha existe no ficheiro de exportaçãos.A iniciar processo de remoção!\n";
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
    print "Processo de remoção concluido!A reiniciar serviço NFS!\n";
    system("/etc/init.d/nfs restart");
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
      print "ERRO: Número de paramentros inválido!\n";
  }
 
  if ($data == 2 && @$data[0] || $data == 4 && @$data[2] || $data == 6 && @$data[4] || $data == 8 && @$data[6] !~
      /^-(dir|n|p|k)$/){
      print "ERRO: Anomalia na passagem de parametros\n";
     exit(1);
  }

    
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
  
  print "A iniciar actualização do ficheiro de exportações\n";
  
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
  print "Actualização do ficheiro de exportações concluida\n";
  system("/etc/init.d/nfs restart");
}

#Função que irá validar se a directoria existe e realizar as opções necessárias
#var $_[0] => vai receber o valor da directoria que queremos adicionar aos exports

sub Valdir($){
  my $dir = $_[0];
  my $tmp_dir = $dir;
  my $choice;
  #verifica se foi especificado uma directoria
  if(!($dir)){
     print "ERRO: É obrigatório especificar uma directoria!\n";
     exit(1);
  }

  #Verifica se partilha ja existe
  my $flag = `cat /etc/exports | grep "/^$dir$/`;
  print $flag;
  if($flag){
    print ("AVISO: Partilha já existe\n");
    print "Pretende especificar outra directoria ?(S/N) \n";
    chomp($choice = <STDIN>);
    if($choice eq "S" || $choice eq "s"){
      print "Introduza a directoria que pretende usar:\n";
      chomp($tmp_dir = <STDIN>);
      &Valdir($tmp_dir);
    }else{
      print "ERRO: Devido a não se poderem ter entrada duplicadas no ficheiro export e a sua escolha ter sido Não o programa irá encerrar!\n";
      exit(1);
    }

  }

  #verificar se directoria existe , caso não existe apresta uma hipotese para cria-la
  if(!-d $dir){
    print "ERRO: Directoria não existe. Pretende que a mesma seja criada?(S/N)\n";
    chomp($choice = <STDIN>);
    if($choice eq "S" || $choice eq "s"){
      mkdir $dir || die $!;
    }else{
      print "ERRO: Visto que não pretende que a directoria seja criada o script irá encerrar!\n";
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
      print "ERRO: O número de permissões não pode ser superior ao número de hosts!\n";
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
    print "Validação do números de elementos das listagens terminadas.\n";
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
    if($tmp_perm !~ /(ro|rw)/){ 
      printf "AVISO: Devido a permissão atribuida ao host $hashlist{$cont}{'host'} ser inválida este host irá ficar com
      permissões de read-only\n";
      $hashlist{$cont}{'perm'} = 'ro';
      $cont++;
    }else{
        $hashlist{$cont}{'perm'} = $tmp_perm;
        $cont++;
    }
  }

  #Atribuição dos valores respectivos as parametros extra
  $cont = 0;
  foreach my $tmp_mod(@mods){
    if($tmp_mod !~ /(no_root_squash|no_subtree_check|sync|async)/){
     printf "AVISO: Devido ao parametro extra atribuido ao host $hashlist{$cont}{'host'} ser inválida este host irá ficar com
     permissões de async!\n";
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
  if($host =~ /^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})/ || $host =~ /^([0-9a-fA-F]{4}|0)(\:([0-9a-fA-F]{4}|0)){7}$/){

    if(!is_ipv4($host) && !is_ipv6($host)){
      print "ERRO: Endereço $host não segue as normas do IPv4 nem IPv6!\n";
      exit(1);
    }
  }elsif($host =~ /^((([a-z]|[0-9]|\-)+)\.)+([a-z])+$/i){
    if(!is_domain($host)){
        print "ERRO: Endereço $host inválido!\n";
        exit(1);
    }     
  }elsif($host eq "*"){
    print "AVISO: Todos os dispositivos terão acesso a esta partilha\n";
  
  }else{
    print "ERRO: Informação do host é inválida!\n";
    exit(1);
  }
}

#Função relativa as estatisticas do serviço
sub showstats($){
  my $param = $_[0];
  if($param !~ /^-(s|c|n|r|v|)/){
    print "ERRO: Parametro extra inválido , faça ./NFS.pl -h para ver todas as opções disponiveis !\n";
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
      system ("nssfstat -n234");
    }elsif($param eq "-r"){
      print "Estatisticas relativas ao RPC do serviço\n";
      system("nfsstat -r");
    }elsif($param eq "-v"){
      print "A imprimir todas as Estatisticas do serviço \n";
      system("nfsstat -v");
    }else{
      print "Não é possivel mostrar Estatisticas para o argumento passado\n";
    }
  }
}