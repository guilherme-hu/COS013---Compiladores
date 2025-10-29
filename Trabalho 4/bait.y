%{
#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <sstream>
#include <algorithm>

using namespace std;

int linha = 1, coluna = 1; 


struct Atributos {
  vector<string> c; // Código

  int linha = 0, coluna = 0;

  int n_args = 0; // Número de argumentos em chamadas de função
  int contador = 0; // Contador de parâmetros
  vector<string> valor_default; // Coletar valores default de parâmetros

  string endereco_funcao; // Usado apenas para definir o endereço da função na regra NOME_FUNCAO e CMD_FUNC

  void clear() {
    c.clear();
    valor_default.clear();
    linha = 0;
    coluna = 0;
    contador = 0;
  }
};


#define YYSTYPE Atributos

extern "C" int yylex();
int yyparse();
void yyerror( const char* st );


vector<string> concatena( vector<string> a, vector<string> b ) {
  a.insert( a.end(), b.begin(), b.end() );
  return a;
}

vector<string> operator+( vector<string> a, vector<string> b ) {
  return concatena( a, b );
}

vector<string>& operator+=( vector<string>& a, const vector<string>& b ) {
  a.insert( a.end(), b.begin(), b.end() );
  return a;
}

vector<string> operator+( vector<string> a, string b ) {
  a.push_back( b );
  return a;
}

vector<string>& operator+=( vector<string>& a, const string& b ) {
  a.push_back( b ); 
  return a;
}

vector<string> operator+( string a, vector<string> b ) {
  return vector<string>{ a } + b;
}


enum TipoDecl { Let = 1, Const, Var };

struct Simbolo {
  TipoDecl tipo;
  int linha;
  int coluna;
};

// Tabela de símbolos
vector< map< string, Simbolo > > ts = { { } };
// .back() é o escopo atual

Atributos declara_variavel( TipoDecl decl, Atributos atrib, int linha, int coluna ) {
  string nome_var = atrib.c[0];

  if (decl == Var){
    if (ts.back().count(nome_var) > 0){
      if (ts.back()[nome_var].tipo != Var){
         cerr <<  "Erro: a variável '" << nome_var << "' ja foi declarada na linha " << ts.back()[nome_var].linha << "." << endl;
         exit(1);
      }
      else {
        atrib.c.clear();
        return atrib;
      }
    }
  }
  else if (ts.back().count(nome_var) > 0){
    cerr << "Erro: a variável '" << nome_var << "' ja foi declarada na linha " << ts.back()[nome_var].linha << "." << endl;
    exit(1);
  }
  
  ts.back()[nome_var].linha = atrib.linha;
  ts.back()[nome_var].coluna = atrib.coluna;
  ts.back()[nome_var].tipo = decl;

  atrib.c = atrib.c + "&";
  return atrib;
}

const string JUMP = "#";
const string JUMP_TRUE = "?";
const string POP = "^";
const string callFunc = "$";


vector<string> resolve_enderecos( vector<string> entrada ) {
  map<string,int> label;
  vector<string> saida;
  for( int i = 0; i < entrada.size(); i++ ) 
    if( entrada[i][0] == ':' ) 
        label[entrada[i].substr(1)] = saida.size();
    else
      saida.push_back( entrada[i] );
  
  for( int i = 0; i < saida.size(); i++ ) 
    if( label.count( saida[i] ) > 0 )
        saida[i] = to_string(label[saida[i]]);
    
  return saida;
}

string gera_label( string prefixo ) {
  static int n = 0;
  return prefixo + "_" + to_string( ++n ) + ":";
}

string define_label( string prefixo ) {
  return ":" + prefixo;
}

void checa_simbolo( string nome, bool modificavel ) {
  for( int i = ts.size() - 1; i >= 0; i-- ) {  
    auto& atual = ts[i];
    
    if( atual.count( nome ) > 0 ) {
      if( modificavel && atual[nome].tipo == Const ) {
        cerr << "Erro: tentativa de modificar uma variável constante ('" << nome << "')." << endl;
        exit( 1 );     
      }
      else 
        return;
    }
  }

  cerr << "Erro: a variável '" << nome << "' não foi declarada." << endl;
  // fprintf( stderr, "Erro: a variável '%s' não foi declarada na linha %d, coluna %d.\n", nome_var.c_str(), atrib.linha, atrib.coluna );
  exit( 1 );     
}

void print( vector<string> codigo ) {
  for( string s : codigo )
    cout << s << " ";
  cout << endl;  
}

vector<string> codigo_funcoes; // Acumula o código de todas funções

%}

%token ID LET CONST VAR PRINT
%token IF ELSE FOR WHILE 
%token FUNCTION RETURN ASM
%token TRUE FALSE
%token CDOUBLE CSTRING CINT
%token AND OR ME_IG MA_IG DIF IGUAL
%token MAIS_IGUAL MAIS_MAIS MENOS_IGUAL MENOS_MENOS


%right '=' MAIS_IGUAL MENOS_IGUAL
%nonassoc OR AND
%nonassoc IGUAL DIF
%nonassoc '<' '>' ME_IG MA_IG
%left '+' '-'
%left '*' '/' '%'

%right '[' '('
%left '.' 
%left MAIS_MAIS MENOS_MENOS

%%

S : CMDs { print( resolve_enderecos( $1.c + "." + codigo_funcoes ) ); }
  ;

CMDs : CMD CMDs { $$.c = $1.c + $2.c; };
     | CMD
     ;

// ; faz parte do comando, bloco por exemplo não termina com ;
CMD : DECL ';'
    | E ';' { $$.c = $1.c + "^"; }
    | CMD_IF
    | CMD_FOR
    | CMD_WHILE
    | PRINT E ';' { $$.c = $2.c + "println" + "#"; }
    | ';' { $$.clear(); } // comando vazio
    | '{' EMPILHA_TS CMDs '}'{ ts.pop_back(); $$.c = "<{" + $3.c + "}>"; }
    | CMD_FUNC 
    | CMD_RETURN
    | E ASM ';' 	{ $$.c = $1.c + $2.c; }
    ;
    
DECL : LET LET_IDs { $$.c = $2.c; }
     | CONST CONST_IDs { $$.c = $2.c; }
     | VAR VAR_IDs {$$.c = $2.c;}
     ;
           
LET_IDs: LET_UM_ID ',' LET_IDs
        { $$.c = $1.c + $3.c; }
        | LET_UM_ID
        ;

LET_UM_ID : ID { $$ = declara_variavel( Let, $1, $1.linha, $1.coluna); }
          | ID '=' E {$$ = declara_variavel( Let, $1, $1.linha, $1.coluna); 
                      $$.c = $$.c + $1.c + $3.c + "=" + "^"; }
          ;

CONST_IDs : CONST_UM_ID ',' CONST_IDs
            { $$.c = $1.c + $3.c; }
            | CONST_UM_ID
            ;

CONST_UM_ID : ID {$$ = declara_variavel ( Const, $1, $1.linha, $1.coluna); }
             | ID '=' E {$$ = declara_variavel( Const, $1, $1.linha, $1.coluna ); 
                         $$.c = $$.c + $1.c + $3.c + "=" + "^";}
             ;

VAR_IDs : VAR_UM_ID ',' VAR_IDs
        { $$.c = $1.c + $3.c; }
        | VAR_UM_ID
        ;

VAR_UM_ID : ID { $$ = declara_variavel( Var, $1, $1.linha, $1.coluna ); }
          | ID '=' E {$$ = declara_variavel( Var, $1, $1.linha, $1.coluna ); 
                      $$.c = $$.c + $1.c + $3.c + "=" + "^";}
          ;


CMD_IF : IF '(' E ')' CMD
         { string fim_if = gera_label("fim_if");
           $$.c = $3.c + "!" + fim_if  + "?" + $5.c + define_label(fim_if);
         }
       | IF '(' E ')' CMD ELSE CMD
         { string fim_if = gera_label("fim_if");
           string else_if = gera_label("else");

           $$.c = $3.c + "!" + else_if + "?" + // Expressão
           $5.c + fim_if + "#" +               // Comando do if  
           define_label(else_if) + $7.c +      // Else
           define_label(fim_if);               // fim if
         }
      ;

CMD_FOR : FOR '(' SF ';' E ';' EF ')' CMD
         { string teste_for = gera_label("teste_for");
           string fim_for = gera_label("fim_for");

           $$.c = $3.c +                             // Atribuição inicial           
           define_label(teste_for) + $5.c +          // Teste do for
           "!" + fim_for + JUMP_TRUE +               // jump
           $9.c +                                    // Comando
           $7.c +                                    // Efeitos
           teste_for + JUMP +                        // Volta para o início
           define_label(fim_for);                    // Fim do for
         }
       ;

EF : E {$$.c = $1.c + "^";}
   | {$$.clear();}
   ;
// SEMPRE QUE TIVER UMA EXPRESSÃO VAZIA, PRECISA DE UM $$.clear()

SF : DECL
   | EF
   ;

CMD_WHILE : WHILE '(' E ')' CMD
           { string teste_while = gera_label("teste_while");
             string fim_while = gera_label("fim_while");

             $$.c = define_label(teste_while) + $3.c +  // Início do while
             "!" + fim_while + JUMP_TRUE +              // Expressão
             $5.c +                                     // Comando
             teste_while + JUMP +                       // Volta para o início
             define_label(fim_while);                   // Fim do while
           }
         ;

EMPILHA_TS : { ts.push_back( map< string, Simbolo >{} ); } // cria uma nova tabela de símbolos na pilha de tabelas
           ;

CMD_FUNC
  : FUNCTION NOME_FUNCAO { $$ = declara_variavel( Var, $2, $2.linha, $2.coluna ); }
    '(' EMPILHA_TS LISTA_PARAMs ')' '{' CMDs '}'
    {
      string lbl_endereco_funcao = gera_label( "func_" + $2.c[0] );
      string definicao_lbl_endereco_funcao = define_label( lbl_endereco_funcao );

      // código da definição (armazenar referência)
      $$.c = $2.c + "&" + $2.c + "{}" + "=" + "'&funcao'" +
             lbl_endereco_funcao + "[=]" + "^";

      // código da função propriamente dita
      vector<string> corpo_funcao = vector<string>{definicao_lbl_endereco_funcao} + $8.c + "'&retorno'" + "@" + "~";

      codigo_funcoes += corpo_funcao;

      ts.pop_back();
    }
  ;

NOME_FUNCAO : ID { $$.endereco_funcao = gera_label( "func_" + $1.c[0] );
                  $$.c = $1.c + "&" + $1.c + "{}"  + "=" + "'&funcao'" +
                  $$.endereco_funcao + "[=]" + "^";
}        

LISTA_PARAMs : PARAMs ',' 
             | PARAMs
             | { $$.clear(); }
             ;
/*            
PARAMs : PARAMs ',' PARAM 
         { declara_variavel(Var, $3, $3.linha, $3.coluna); 

          $$.c = $1.c + $3.c + "&" + $3.c + "arguments" + "@" + to_string( $1.contador ) + "[@]" + "=" + "^"; 
          
          if( $3.valor_default.size() > 0 ) {
             string lbl_fim_if = gera_label( "fim_default_if" );
             $$.c += $3.c + "@" + "undefined" + "@" + "==" +
                      lbl_fim_if + "?" +
                      $3.c + $3.valor_default + "=" + "^" +
                      define_label( lbl_fim_if );
           }
           $$.contador = $1.contador + $3.contador; }
           
     | PARAM { // a & a arguments @ 0 [@] = ^ 
        declara_variavel( Var, $1, $1.linha, $1.coluna );
        $$.c = $1.c + "&" + $1.c + "arguments" + "@" + "0" + "[@]" + "=" + "^"; 
                
        if( $1.valor_default.size() > 0 ) {
            string lbl_fim_if = gera_label( "fim_default_if" );
            string def_lbl_fim_if = define_label( lbl_fim_if );
            $$.c += $1.c + "@" + "undefined" + "@" + "==" +
                      lbl_fim_if + "?" +
                      $1.c + $1.valor_default + "=" + "^" +
                      define_label( lbl_fim_if );
        }
        $$.contador = 1; 
       }
     ;
     // se colocar vazio aqui, lista_args não pode ser vazio, e aqui aceitamos final com ;
     
PARAM : ID {  $$.c = $1.c;      
        $$.valor_default.clear();
        $$.linha = $1.linha;
        $$.coluna = $1.coluna;
      }
      | ID '=' E { // Código do IF
        $$.c = $1.c;
        $$.valor_default = $3.c;
        $$.linha = $1.linha;
        $$.coluna = $1.coluna;
        }
      ; */

PARAMs : PARAMs ',' ID '=' E {$$.contador = $3.contador + 1;} 
        | PARAMs ',' ID {$$.contador = $3.contador + 1;} 
        | ID '=' E {$$.contador = 0;} 
        | ID {$$.contador = 0;}
     ;
     // se colocar vazio aqui, lista_args não pode ser vazio, e aqui aceitamos final com ;
     

CMD_RETURN : RETURN E ';' { $$.c = $2.c + "'&retorno'" + "@" + "~"; }
           | RETURN ';' { $$.c = vector<string>{"undefined"} + "@" + "'&retorno'" + "@" + "~"; }  
           ;

LVALUE : ID { checa_simbolo( $1.c[0], false ); $$.c = $1.c; }
       ;

LVALUEPROP : E '[' E ']' { $$.c = $1.c + $3.c; }
           | E '.' ID { $$.c = $1.c + $3.c; }
           ;

// Operadores binários e atribuição
E : LVALUE { checa_simbolo( $1.c[0], false ); $$.c = $1.c + "@"; } 
  | LVALUEPROP { checa_simbolo( $1.c[0], false ); $$.c = $1.c + "[@]"; }
  | LVALUE '=' E { checa_simbolo( $1.c[0], true ); $$.c = $1.c + $3.c + "="; }
  | LVALUEPROP '=' E { checa_simbolo( $1.c[0], true ); $$.c = $1.c + $3.c + "[=]"; }
  | LVALUE MAIS_IGUAL E     { checa_simbolo( $1.c[0], true ); $$.c = $1.c + $1.c + "@" + $3.c + "+" + "="; } // a += e  => a a @ e + =
  | LVALUE MENOS_IGUAL E    { checa_simbolo( $1.c[0], true ); $$.c = $1.c + $1.c + "@" + $3.c + "-" + "="; } // a -= e  => a a @ e - =
  | LVALUEPROP MAIS_IGUAL E { checa_simbolo( $1.c[0], true ); $$.c = $1.c + $1.c + "[@]" + $3.c + "+" + "[=]"; }  // a[i] += e  => a[i] a[i] [@] e + [=]
  | LVALUEPROP MENOS_IGUAL E{ checa_simbolo( $1.c[0], true ); $$.c = $1.c + $1.c + "[@]" + $3.c + "-" + "[=]"; }  // a[i] -= e  => a[i] a[i] [@] e - [=]
  | E '<' E { $$.c = $1.c + $3.c + "<"; }
  | E '>' E { $$.c = $1.c + $3.c + ">"; }
  | E ME_IG E { $$.c = $1.c + $3.c + "<="; }
  | E MA_IG E { $$.c = $1.c + $3.c + ">="; }
  | E DIF E { $$.c = $1.c + $3.c + "!="; }
  | E IGUAL E { $$.c = $1.c + $3.c + "=="; }
  | E AND E { $$.c = $1.c + $3.c + "&&"; }
  | E OR E { $$.c = $1.c + $3.c + "||"; }
  | E '+' E { $$.c = $1.c + $3.c + "+"; }
  | E '-' E { $$.c = $1.c + $3.c + "-"; }
  | E '*' E { $$.c = $1.c + $3.c + "*"; }
  | E '/' E { $$.c = $1.c + $3.c + "/"; }
  | E '%' E { $$.c = $1.c + $3.c + "%"; }
  | '-' E     { $$.c = "0" + $2.c + "-"; } // unário -
  | '+' E     { $$.c = $2.c; } // unário +
  | MAIS_MAIS LVALUE { checa_simbolo( $1.c[0], true ); $$.c = $2.c + $2.c + "@" + "1" + "+" + "="; }
  | MENOS_MENOS LVALUE {checa_simbolo( $1.c[0], true ); $$.c = $2.c + $2.c + "@" + "1" + "-" + "="; }
  | F
  ;


// Operadores unários
F : CDOUBLE
  | CINT
  | CSTRING
  | LVALUE MAIS_MAIS { checa_simbolo( $1.c[0], true ); $$.c = $1.c + "@" + $1.c + $1.c + "@" + "1" + "+" + "=" + "^"; }
  | LVALUE MENOS_MENOS { checa_simbolo( $1.c[0], true ); $$.c = $1.c + "@" + $1.c + $1.c + "@" + "1" + "-" + "=" + "^"; } 
  | LVALUEPROP MAIS_MAIS { checa_simbolo( $1.c[0], true ); $$.c = $1.c + "[@]" + $1.c + $1.c + "[@]" + "1" + "+" + "[=]" + "^"; }
  | LVALUEPROP MENOS_MENOS { checa_simbolo( $1.c[0], true ); $$.c = $1.c + "[@]" + $1.c + $1.c + "[@]" + "1" + "-" + "[=]" + "^"; }
  | '(' E ')' { $$.c = $2.c; }
  | '[' ']' { $$.c = vector<string>{"[]"}; }
  | '{' '}' { $$.c = vector<string>{"{}"}; }
  | E '(' LISTA_ARGs ')' { $$.c = $3.c + to_string( $3.n_args ) + $1.c + "$"; }
  ;
  
LISTA_ARGs
  : ARGs ','        { $$.c = $1.c; $$.n_args = $1.n_args; } // vírgula final aceita
  | ARGs            { $$.c = $1.c; $$.n_args = $1.n_args; }
  |                 { $$.clear(); $$.n_args = 0; }
  ;

ARGs
  : ARGs ',' E
    { $$.c = $1.c + $3.c;
      $$.n_args = $1.n_args + 1; }
  | E
    { $$.c = $1.c;
      $$.n_args = 1; }
  ;


%%

#include "lex.yy.c"

void yyerror( const char* st ) {
   puts( st ); 
   printf( "Proximo a: %s\n", yytext );
   exit( 0 );
}

int main( int argc, char* argv[] ) {
  yyparse();
  
  return 0;
}