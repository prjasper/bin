BIN = $(HOME)/.git/hooks
SRC = $(wildcard *.sh)
EXE := $(patsubst %.sh,$(BIN)/%,$(SRC))

$(BIN)/%: $(PWD)/%.sh
	chmod a+x $<
	ln -s $^ $@ 

all: $(EXE)

$(EXE): | $(BIN)

$(BIN):
	mkdir -p $(BIN)

.PHONY: clean
clean:
	rm $(EXE)
