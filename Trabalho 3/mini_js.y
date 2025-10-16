%{
#include <iostream>
#include <string>
#include <vector>
#include <map>

using namespace std;

int linha = 1, coluna = 1; 


struct Atributos {
  vector<string> c; // Código

  int linha = 0, coluna = 0;

  void clear() {
    c.clear();
    linha = 0;
    coluna = 0;
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

map< string, Simbolo > ts; // Tabela de símbolos

Atributos declara_variavel( TipoDecl decl, Atributos atrib ){
  string nome_var = atrib.c[0];

  if (decl == Var){
    if (ts.count(nome_var) > 0){
      if (ts[nome_var].tipo != Var){
        yyerror("Variável já declarada com let ou var");
      }
      else {
        atrib.c.clear();
        return atrib;
      }
    }
  }
  else if (ts.count(nome_var) > 0){
    yyerror("Variável já declarada");
  }
  ts[nome_var].linha = atrib.linha;
  ts[nome_var].coluna = atrib.coluna;
  ts[nome_var].tipo = decl;

  atrib.c = atrib.c + "&";
  return atrib;
}

const string JUMP = "#";
const string JUMP_TRUE = "?";
const string POP = "^";


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

void verifica_uso( Atributos atrib ){
  string nome_var = atrib.c[0];
  if (ts.count(nome_var) == 0){
    fprintf( stderr, "Erro: a variável '%s' não foi declarada na linha %d, coluna %d.\n", nome_var.c_str(), atrib.linha, atrib.coluna );
    exit(1);
  }
}

void verifica_const( Atributos atrib ){
  string nome_var = atrib.c[0];
    if (ts.count(nome_var) > 0 && ts[nome_var].tipo == Const){
    fprintf( stderr, "Erro: tentativa de modificar uma variável constante ('%s') na linha %d.\n", nome_var.c_str(), atrib.linha );
    exit(1);
  }
}

void print( vector<string> codigo ) {
  for( string s : codigo )
    cout << s << " ";
  cout << endl;  
}

%}

%token ID LET CONST VAR PRINT
%token IF ELSE FOR WHILE
%token CDOUBLE CSTRING CINT
%token AND OR ME_IG MA_IG DIF IGUAL
%token MAIS_IGUAL MAIS_MAIS MENOS_IGUAL MENOS_MENOS


%right '=' MAIS_IGUAL MENOS_IGUAL
%left OR
%left AND
%nonassoc IGUAL DIF
%nonassoc '<' '>' ME_IG MA_IG
%left '+' '-'
%left '*' '/' '%'

%left '.' '['

%%

S : CMDs { print( resolve_enderecos( $1.c + "." ) ); }
  ;

CMDs : CMD CMDs { $$.c = $1.c + $2.c; };
     | CMD
     ;

// ; faz parte do comando, bloco por exemplo não termina com ;
CMD : DECL ';'
    | E ';' { $$.c = $1.c + "^"; }
    | CMD_IF
    /* 
    | CMD_FOR
    | CMD_WHILE */
    | PRINT E ';' { $$.c = $2.c + "println" + "#"; }
    | ';'
    ;
    
DECL : LET LET_IDs { $$.c = $2.c; }
     | CONST CONST_IDs { $$.c = $2.c; }
     | VAR VAR_IDs {$$.c = $2.c;}
     ;
           
LET_IDs: LET_UM_ID ',' LET_IDs
        { $$.c = $1.c + $3.c; }
        | LET_UM_ID
        ;

LET_UM_ID : ID { $$ = declara_variavel( Let, $1 ); }
          | ID '=' E {$$ = declara_variavel( Let, $1 ); 
                      $$.c = $$.c + $1.c + $3.c + "=" + "^"; }
          ;

CONST_IDs : CONST_UM_ID ',' CONST_IDs
            { $$.c = $1.c + $3.c; }
            | CONST_UM_ID
            ;

CONST_UM_ID : ID {$$ = declara_variavel ( Const, $1); }
             | ID '=' E {$$ = declara_variavel( Const, $1 ); 
                         $$.c = $$.c + $1.c + $3.c + "=" + "^";}
             ;

VAR_IDs : VAR_UM_ID ',' VAR_IDs
        { $$.c = $1.c + $3.c; }
        | VAR_UM_ID
        ;

VAR_UM_ID : ID { $$ = declara_variavel( Var, $1 ); }
          | ID '=' E {$$ = declara_variavel( Var, $1 ); 
                      $$.c = $$.c + $1.c + $3.c + "=" + "^";}
          ;


CMD_IF : IF '(' E ')' BLOCO
         { string fim_if = gera_label("fim_if");
           $$.c = $3.c + "!" + fim_if  + "?" + $5.c + define_label(fim_if);
         }
       | IF '(' E ')' BLOCO ELSE BLOCO
         { string fim_if = gera_label("fim_if");
           string else_if = gera_label("else");

           $$.c = $3.c + "!" + else_if + "?" + // Expressão
           $5.c + fim_if + "#" +               // Comando do if  
           define_label(else_if) + $7.c +      // Else
           define_label(fim_if);               // fim if
         }
      ;

BLOCO : CMD
      | '{' CMDs '}' { $$.c = $2.c; }
      ;
/* 
CMD_FOR : FOR '(' SF ';' E ';' EF ')' CMD
         { string teste_for = gera_label("teste_for");
           string fim_for = gera_label("fim_for");

           $$.c = $3.c + define_label(teste_for) +   // Início do for            
           $5.c + "!" + fim_for + JUMP_TRUE +        // jump
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

             $$.c = $3.c + define_label(teste_while) +  // Início do while
             "!" + fim_while + JUMP_TRUE +              // Expressão
             $5.c +                                     // Comando
             teste_while + JUMP +                       // Volta para o início
             define_label(fim_while);                   // Fim do while
           }
         ; */
   
LVALUE : ID { verifica_uso( $1 ); $$.c = $1.c; }
       ;

LVALUEPROP : E '[' E ']' { $$.c = $1.c + $3.c; }
           | E '.' ID { $$.c = $1.c + $3.c; }
           ;

// Operadores binários e atribuição
E : LVALUE '=' E { verifica_uso( $1 ); $$.c = $1.c + $3.c + "="; }
  | LVALUEPROP '=' E { verifica_uso( $1 ); $$.c = $1.c + $3.c + "[=]"; }
  | LVALUE MAIS_IGUAL E     { verifica_uso( $1 ); $$.c = $1.c + $1.c + "@" + $3.c + "+" + "="; } // a += e  => a a @ e + =
  | LVALUE MENOS_IGUAL E    { verifica_uso( $1 ); $$.c = $1.c + $1.c + "@" + $3.c + "-" + "="; } // a -= e  => a a @ e - =
  | LVALUEPROP MAIS_IGUAL E { $$.c = $1.c + $1.c + "[@]" + $3.c + "+" + "[=]"; }  // a[i] += e  => a[i] a[i] [@] e + [=]
  | LVALUEPROP MENOS_IGUAL E{ $$.c = $1.c + $1.c + "[@]" + $3.c + "-" + "[=]"; }  // a[i] -= e  => a[i] a[i] [@] e - [=]
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
  | F
  ;

// Operadores unários
F : LVALUE { $$.c = $1.c + "@"; } 
  | LVALUEPROP { $$.c = $1.c + "[@]"; }
  | CDOUBLE
  | CINT
  | CSTRING
  | LVALUE MAIS_MAIS {$$.c = $1.c + "@" + $1.c + $1.c + "@" + "1" + "+" + "=" + "^"; }
  | LVALUE MENOS_MENOS {$$.c = $1.c + "@" + $1.c + $1.c + "@" + "1" + "-" + "=" + "^"; } 
  | '(' E ')' { $$.c = $2.c; }
  | '[' ']' { $$.c = vector<string>{"[]"};}
  | '{' '}' { $$.c = vector<string>{"{}"}; }
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