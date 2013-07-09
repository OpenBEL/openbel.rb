#!/usr/bin/env jruby
# vim: ts=2 sw=2:
raise "JRuby required" unless (RUBY_PLATFORM =~ /java/)

require 'addressable/uri'
require 'json'
require 'pathname'
require 'sinatra/base'
require 'zlib'

require_relative 'bel'
require_relative 'sesame'
import org.openrdf.model.vocabulary.RDF
import org.openrdf.query.QueryLanguage

class KnowledgeNetworks < Sinatra::Base

  ENV['OPENBEL_HOME'] ||= File.expand_path(File.dirname(__FILE__))
  ENV['DATABASE_DIR'] ||= (Pathname.new(ENV['OPENBEL_HOME']) + 'db').to_s
  repo = Sesame.initialize(ENV['DATABASE_DIR'])

  post '/knowledge_networks' do
    # guards
    return if not valid_content_length(request)
    return if not is_json(request)
    request.body.rewind
    data = JSON.parse(request.body.read)
    name = data['knowledge_network']['name']
    cxn = repo.sail.connection
    vft = repo.sail.value_factory
    cxn.begin
    begin
      kn = vft.create_bnode(name)
      kn_type = vft.create_uri(Sesame::TYPE_URI, 'knowledge_network')
      cxn.add_statement(kn, RDF::TYPE, kn_type, vft.create_bnode("DEFAULT"))
    rescue
      cxn.rollback
      status 500
      return
    ensure
      cxn.commit
      cxn.close
    end

    status 201
    headers 'Location' => make_url("/knowledge_networks/#{name}")
  end

  get '/knowledge_networks' do
    cxn = repo.connection
    begin
      qs = "SELECT ?s WHERE {?s a <#{Sesame::TYPE_URI}knowledge_network>}"
      query = cxn.prepare_tuple_query(QueryLanguage::SPARQL, qs)
      result = query.evaluate
      kn = []
      begin
        while result.has_next do
          binding = result.next
          value = binding.get_value('s')
          kn << make_url("/knowledge_networks/#{value.string_value}")
        end
      rescue
        status 500
        return
      ensure
        result.close
      end

      headers 'Content-Type' => 'application/json'
      JSON.unparse({'knowledge_networks' => kn})
    ensure
      cxn.close
    end
  end

  get '/knowledge_networks/:name' do
    nil
  end

  post '/knowledge_networks/:name/documents' do
    # guards
    return if not valid_content_length(request)
    unless params.has_key?('file')
      status 422
      return
    end
    file_hash = params['file']
    ctype = file_hash[:type]
    unless ['text/plain', 'application/gzip'].include? ctype
      status 415
      return
    end

    name = params[:name]
    fname = file_hash[:filename]
    document_uri = BEL.create_document(fname, repo)
    compressed = (ctype == 'application/gzip')
    BEL.add_document(document_uri, file_hash[:tempfile],
                     (ctype == 'application/gzip'), repo)
    puts "finishing"
    status 201
    headers 'Location' => make_url("/knowledge_networks/#{name}/#{fname}")
  end

  post '/knowledge_networks/:name/statements' do
    # guards
    return if not valid_content_length(request)
    return if not is_json(request)
    request.body.rewind
    data = JSON.parse(request.body.read)
    bel_statement = data['statement']['bel']
    BEL.add_statement_string(bel_statement, nil, nil, repo)
    status 201
  end

  get '/knowledge_networks/:name/statements/:subject/:rel/:object' do
    nil
  end

  get '/knowledge_networks/:name/statements' do
    nil
  end

  helpers do
    def make_url(path)
      url(Addressable::URI::encode(path))
    end

    def valid_content_length(request)
      if not request.content_length or request.content_length.to_i <= 0 then
          status 411 # length required
          return false
      end
      true
    end

    def is_json(request)
      if not request.content_type or \
         not request.content_type.include? 'application/json' then
         status 415 # unsupported media type
         return false
      end
      true
    end
  end

  run! if app_file == $0

  at_exit do
    repo.sail.shutDown
  end
end
