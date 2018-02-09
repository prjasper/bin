# bin/git-hooks
This repository contains a set of git hooks that I have found useful in my work.

To enable these hooks, first configure git to recognize hooks in your .git/hooks directory:

    git config --global core.hooksPath $HOME/.git/hooks

## Installing
To install these tools, clone this repository and type these commands:

    cd bin/git-hooks # where this is your cloned repo
    make

## Uninstalling
To uninstall these tools, type these commands:

    cd bin/git-hooks # where this is your cloned repo
    make clean
