#!/usr/bin/env jruby
# vim: ts=2 sw=2:

raise "JRuby required" unless (RUBY_PLATFORM =~ /java/)
require_relative 'sesame'

repo = Sesame.initialize('db')
Sesame.load(repo, 'entities.nq')
