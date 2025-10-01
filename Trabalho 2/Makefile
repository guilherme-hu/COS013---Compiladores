LEX=flex
CC=gcc

all: main tradutor

main: main.lex
	$(LEX) -o main.c main.lex
	$(CC) -o main main.c -lfl

tradutor: tradutor.lex
	$(LEX) -o lex.yy.c tradutor.lex
	$(CC) -o lex.yy lex.yy.c -lfl

clean:
	rm -f main lex.yy main.c lex.yy.c