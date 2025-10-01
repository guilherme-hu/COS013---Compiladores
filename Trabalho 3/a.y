%{
#include <string>
#include <stdio.h>
#include <stdlib.h>
#include <iostream>

using namespace std;

struct Atributos {
  string e;
  string d;
};

#define YYSTYPE Atributos

int yylex();
int yyparse();
void yyerror(const char *);

%}

%token NUM CTE X

// Start indica o símbolo inicial da gramática
%start S

%%

S : E { cout << "f(x)     = " << $1.e << endl
             << "df(x)/dx = " << $1.d << endl; }
  ;

E : E '+' T { $$.e = $1.e + " + " + $3.e;
              $$.d = $1.d + " + " + $3.d; }
  | E '-' T { $$.e = $1.e + " - " + $3.e; 
              $$.d = $1.d + " - " + $3.d; }
  | T
  ;
  
T : T '*' P { $$.e = $1.e + "*" + $3.e; 
              $$.d = "(" + $1.d + "*" + $3.e + " + " + $1.e + "*" + $3.d + ")"; }
  | T '/' P { $$.e = $1.e + "/" + $3.e; 
              $$.d =  "(" + "(" + $1.d + "*" + $3.e + " - " + $1.e + "*" + $3.d + ")"
                   + "/" + $3.e + "^2" + ")"
              ; }
  | P
  ;
  
P : F '^' NUM { $$.e = $1.e + "^" + $3.e;
		$$.d = $3.e + "*" + $1.d + "*" + $1.e + "^" + 
		       to_string( (stod( $3.e ) - 1) );  }
  | F '^' CTE { $$.e = $1.e + "^" + $3.e;
		$$.d = $3.e + "*" + $1.d + "*" + $1.e + "^" + 
			   "("+ $3.e + "-1)";  }
  | F   
  ;
  
F : NUM
  | CTE
  | X
  | '(' E ')' { $$.e = "(" + $2.e + ")"; 
                $$.d = "(" + $2.d + ")"; }
  // | sen(E) {E' * cos(E)}
  ;

  // $$ = $1
  
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

// deeplink