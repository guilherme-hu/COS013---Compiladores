%{
string lexema;
bool expr = false;
%}

/* Coloque aqui definições regulares */

D           [0-9]
L           [a-zA-Z_]

FOR         ([fF][oO][rR])
IF          ([iI][fF])

ID          ({L}|[\$])({L}|{D})*

INT         {D}+
FLOAT       {D}+(\.{D}+)?([eE][+\-]?{D}+)?

STRING      (\"(\\\"|\"\"|[^"])*\")|\'(\\\'|\'\'|[^'])*\'

STRING2     (\`(([^`$]|\$[^{])|{WS})*\`)|(\`([^`]|{WS})*\$\{)|(\}([^`]|{WS})*\`)

COMENTARIO  (\/\*(([^*]|\*[^/])|{WS})*\*\/)|(\/\/([^\n\r\t])*)

ERRO        ({L}|[\$])({L}|{D}|[\$])*

WS          [ \n\r\t]+

%%
    /* Padrões e ações. Nesta seção, comentários devem ter um tab antes */

{WS}	{ /* ignora espaços, tabs e '\n' */ } 

{FOR}   { lexema = yytext; return _FOR; }
{IF}    { lexema = yytext; return _IF; }
 
">="    { lexema = yytext; return _MAIG; }
"<="    { lexema = yytext; return _MEIG; }
"=="    { lexema = yytext; return _IG; }
"!="    { lexema = yytext; return _DIF; }

{INT}   { lexema = yytext; return _INT; }
{FLOAT} { lexema = yytext; return _FLOAT; }

{ID}    { lexema = yytext; 
        if (expr) { 
            expr = false;
            return _EXPR;
        }
        else return _ID;}

{STRING} {
    bool aspasimples = false;
    if (yytext[0] == '\'') aspasimples = true;
    string s = string(yytext + 1, yyleng - 1); // Remove aspas externas
    string result;
    for (int i = 0; i < s.length()-1; ++i) {
        if (s[i] == '\\') { // Se for \" ou \', adiciona só a aspa
            if (s[i+1] == '"' || s[i+1] == '\'') {
                result += s[i+1];
                ++i; 
            } else {
                result += s[i];
            }
        } else if (s[i] == '"' && !aspasimples){ // Se for "" dentro de aspas duplas
            if (s[i+1] == '"'){
                result += s[i+1];
                ++i;
            } 
            else {
                result += s[i];
            }
        } else if (s[i] == '\'' && aspasimples){ // Se for '' dentro de aspas aspasimples
            if (s[i+1] == '\''){
                result += s[i+1];
                ++i;
            } 
            else {
                result += s[i];
            }
        } else {
            result += s[i];
        }
    }
    lexema = result;
    return _STRING;
}

{STRING2}   { 
 if (yytext[yyleng-1] == '`')
        lexema = string(yytext + 1, yyleng - 2); // Remove ` inicial e final
    else if (yytext[yyleng-2] == '$' && yytext[yyleng-1] == '{'){
        lexema = string(yytext + 1, yyleng - 3); // Remove ` inicial e dois ultimos caracteres
        expr = true;
    }
    return _STRING2;
}

{COMENTARIO} { lexema = yytext; return _COMENTARIO; }

{ERRO}  { printf("Erro: Identificador invalido: %s\n", yytext); }

.       { lexema = yytext; return *yytext; 
          /* Essa deve ser a última regra. Dessa forma qualquer caractere isolado será retornado pelo seu código ascii. */ }

%%

/* Não coloque nada aqui - a função main é automaticamente incluída na hora de avaliar e dar a nota. */