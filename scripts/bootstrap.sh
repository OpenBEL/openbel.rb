#!/usr/bin/env bash
#
# usage: bootstrap.sh
# description: idempotent script that establishes ruby version + gems

#settings
RUBY=jruby-1.7.4

#colors
ESC="\x1b["
RESET=$ESC"39;49;00m"
RED=$ESC"31;01m"
GREEN=$ESC"32;01m"
YELLOW=$ESC"33;01m"

#move to root
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/../
cd "${DIR}" || exit 1

#install rbenv/ruby-build if missing
if [ ! -d "$HOME/.rbenv" ]; then
    echo -e "${YELLOW}action: installing rbenv to $HOME/.rbenv${RESET}"
    git clone git://github.com/sstephenson/rbenv.git $HOME/.rbenv
    git clone https://github.com/sstephenson/ruby-build.git $HOME/.rbenv/plugins/ruby-build
else
    echo -e "${GREEN}rbenv installation [x]${RESET}"
fi

#infect PATH and wire bash completion
hash rbenv > /dev/null 2>&1
if [ $? != 0 ] && [ -f "$HOME/.bashrc" ]; then
    echo -e "${YELLOW}action: prepending $HOME/.rbenv/bin to PATH"
    echo -e "${YELLOW}action: consider adding to $HOME/.bashrc"
    export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
    eval "$(rbenv init -)"
else
    echo -e "${GREEN}rbenv on PATH [x]${RESET}"
fi

#install RUBY version if missing
RUBY_VERSION=$(rbenv version | cut -d' ' -f1)
if [ "$RUBY_VERSION" != "$RUBY" ]; then
    echo -e "${YELLOW}action: installing ${RUBY}${RESET}"
    rbenv install $RUBY
    rbenv rehash
    rbenv local $RUBY
else
    echo -e "${GREEN}ruby [x]${RESET}"
fi

#install bundler; rehash for bundle shim
gem install --conservative -q bundler && rbenv rehash

#install gems in Gemfile
bundle install
rbenv rehash
echo -e "${GREEN}gems [x]${RESET}"
