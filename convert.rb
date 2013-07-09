#!/usr/bin/env jruby
# vim: ts=2 sw=2:

require 'addressable/uri'
require 'rdf'
require 'rdf/nquads'
require 'rdf/ntriples'

E = RDF::Vocabulary.new("http://www.selventa.com/bel/entity/")
A = RDF::Vocabulary.new("http://www.selventa.com/bel/annotation/")
CTX = E['entity-graph']

# build uuid hash
hash = Hash.new {|hash,key| hash[key] = []}
Dir['data/*beleq'].each do |path|
  name = /data\/(\w+).beleq/.match(path)[1]
  File.foreach(path) do |l|
    ident, uuid = l.split(%r{\|}).each { |v| v.strip! }
    hash[uuid] << "#{name}/#{ident}"
  end
end

def write_ns_stmts(hash, path, writer, out_file)
  # TODO Documentation!
  name = /data\/(\w+).beleq/.match(path)[1]
  out_file << writer.dump([RDF::Statement.new(
    E[name], RDF.type, RDF::SKOS.ConceptScheme)])
  File.foreach(path) do |l|
    ident, uuid = l.split(%r{\|}).each { |v| v.strip! }
    res_uri = RDF::URI(Addressable::URI.encode(E["#{name}/#{ident}"].to_s))

    out_file << writer.dump([RDF::Statement.new(
      res_uri, RDF.type, RDF::SKOS.Concept)])
    out_file << writer.dump([RDF::Statement.new(
      res_uri, RDF::SKOS.inScheme, E[name])])
    out_file << writer.dump([RDF::Statement.new(
      res_uri, RDF::SKOS.prefLabel, ident)])

    hash[uuid].each do |e|
      match_uri = RDF::URI(Addressable::URI.encode(E[e].to_s))
      out_file << writer.dump([RDF::Statement.new(
        res_uri, RDF::SKOS.exactMatch, match_uri)])
    end
  end
end

def write_annotation_stmts(path, writer, out_file)
  # TODO Documentation!
  name = /data\/(\w+).belanno/.match(path)[1]
  out_file << writer.dump([RDF::Statement.new(
    A[name], RDF.type, RDF::SKOS.ConceptScheme)])
  File.foreach(path) do |l|
    value = l.split(%r{\|})[0].strip
    res_uri = RDF::URI(Addressable::URI.encode(A["#{name}/#{value}"].to_s))

    out_file << writer.dump([RDF::Statement.new(
      res_uri, RDF.type, RDF::SKOS.Concept)])
    out_file << writer.dump([RDF::Statement.new(
      res_uri, RDF::SKOS.inScheme, A[name])])
    out_file << writer.dump([RDF::Statement.new(
      res_uri, RDF::SKOS.prefLabel, value)])
  end
end

writer = RDF::Writer.for(:nquads)
File.open("entities.nq", "w") do |file|
  Dir['data/*belanno'].each do |path|
    write_annotation_stmts(path, writer, file)
  end

  Dir['data/*beleq'].each do |path|
    write_ns_stmts(hash, path, writer, file)
  end
end
