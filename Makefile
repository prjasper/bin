SRC = $(wildcard *.sh)
EXE := $(patsubst %.sh,$(HOME)/bin/%,$(SRC))

$(HOME)/bin/%: $(PWD)/%.sh
	chmod a+x $<
	ln -s $^ $@ 

all: $(EXE)
