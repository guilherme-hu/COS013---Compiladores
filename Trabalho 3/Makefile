all: derivada entrada.txt
	./derivada < entrada.txt

lex.yy.c: derivada.lex
	lex derivada.lex

y.tab.c: derivada.y
	yacc derivada.y

derivada: lex.yy.c y.tab.c
	g++ -o derivada y.tab.c -ll