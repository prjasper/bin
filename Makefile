BIN = $(HOME)/bin
SRC = $(wildcard *.sh)
EXE := $(patsubst %.sh,$(BIN)/%,$(SRC))

$(BIN)/%: $(PWD)/%.sh
	chmod a+x $<
	ln -s $^ $@ 

all: $(EXE)

.PHONY: clean
clean:
	rm $(EXE)
