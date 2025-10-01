%{
#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include <string>
#include <map>

using namespace std;

int token;

void S();
void C();
void A();
void E();
void T();
void U();
void P();
void Fat();
void F();
void Arg();

void casa( int );
void print( string );
void erro( string );

enum { tk_id = 256, tk_num, tk_str, f_print };

map<int,string> nome_tokens = {
  { tk_id, "nome de identificador" },
  { tk_num, "constante inteira" },
  { tk_str, "string" },
  { f_print, "função print" },
};

string lexema;
%}


WS	[ \n\r\t]+
D	[0-9]
L	[A-Za-z_]

NUM	    {D}+(\.{D}+)?([eE][+\-]?{D}+)?
ID      ({L})({L}|{D})*
STRING  \"(\\\"|\"\"|[^"])*\"
PRINT   [Pp][Rr][Ii][Nn][Tt]

%%

{WS}  		{ }

{PRINT}     { lexema = yytext; return f_print; }

{NUM} 		{ lexema = yytext; return tk_num; }

{ID}		{ lexema = yytext; return tk_id; }

{STRING} 	{ lexema = yytext; return tk_str; }

.		    { lexema = yytext; return yytext[0]; }

%%


// Deve ser um arquivo lex com o seu analisador sintático na parte final

int next_token() {
  return yylex();
}

string nome_token( int token ) {
  if( nome_tokens.find( token ) != nome_tokens.end() )
    return nome_tokens[token];
  else {
    string r;
    
    r = token;
    return r;
  }
}

void print(string s) {
    cout << s << " ";
}

void erro(string s) {
    cout << endl << "Erro: " << s << endl;
    exit(1);
}

void casa( int esperado ) {
  if( token == esperado )
    token = next_token();
  else {
      cout << "Esperado " << nome_token( esperado ) 
	   << " , encontrado: " << nome_token( token ) << endl;
    exit( 1 );
  }
}

void S() { // Expressões gerais
  C();
  if (token != 0) S();
}

void C() {
  switch( token ) {
    case tk_id: A();
             casa( ';' );
             print(" ^");
             break;
           
    case f_print: token = next_token();
             E();
             print("print #");
             casa( ';' );
             break;
  }
}

void A() { // atribuição
// Guardamos o lexema pois a função 'casa' altera o seu valor.
  string temp = lexema; 
  casa( tk_id );
  print( temp );
  casa( '=' );
  E();
  print( "=" );
}

void E() { // soma e subtração
  T();
  
  while( 1 ) 
    switch( token ) {
      case '+' : casa( '+' ); T(); print( "+" ); break;
      
      case '-' : casa( '-' ); T(); print( "-" ); break;
      
      default: return; // epsilon
    }
}


void T() { // multiplicação e divisão
  U();
  
  while( 1 ) 
    switch( token ) {
      case '*' : casa( '*' ); U(); print( "*"); break;
      
      case '/' : casa( '/' ); U(); print( "/" ); break;
      
      default: return; // epsilon
    }
}


void U(){ // unário
    switch( token ) {
      case '-' : casa( '-' ); print("0"); U(); print( "-" ); break;
      case '+' : casa( '+' ); U(); break;
      default: P(); 
    }
}

void P() { // potência
    Fat();

    switch( token ) {
      case '^' : casa( '^' ); U(); print( "power #"); break;
      default: return; // epsilon
    }
}

void Fat(){ // Fatorial
    F();
    switch( token ) {
      case '!' : casa( '!' ); print( "fat #"); break;
      default: return; // epsilon
    }
}   


void F() { // elemento
  switch( token ) {
    
    case tk_id : {
      string temp = lexema;
      casa( tk_id );  
    
      switch( token ){
        case '(' : 
          casa( '(' );
          Arg(); 
          casa( ')' );
          print( temp + " #" );
          break;
        default: print( temp + " @" );
      }
    }
    break;

    case tk_num : {
      string temp = lexema;
      casa( tk_num ); print( temp ); }
      break;
    case tk_str : {
      string temp = lexema;
      casa( tk_str ); print( temp ); }
      break;
    case '(': 
      casa( '(' ); E(); casa( ')' ); break;
    default:
      erro( "Operando esperado, encontrado: " + lexema );
  }
}

void Arg(){
  E();
  
  while( 1 ) 
    switch( token ) {
      case ',' : casa( ',' ); E(); print( " " ); break;
      
      default: return; // epsilon
    }
}


int main() {
  token = next_token();
  S();

  return 0;
}