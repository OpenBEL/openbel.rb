# vim: ts=2 sw=2:
raise "JRuby required" unless (RUBY_PLATFORM =~ /java/)
Dir['libs/sesame/*.jar'].each { |jar| require jar }
import org.openrdf.repository.Repository
import org.openrdf.repository.sail.SailRepository
import org.openrdf.sail.nativerdf.NativeStore
import org.openrdf.rio.Rio
import org.openrdf.rio.RDFHandler

module Sesame
  
  BASE_URI = 'http://www.selventa.com/bel/'
  HAS_PARAM = BASE_URI + 'hasParameter'
  TYPE_URI = BASE_URI + 'type/'
  ENTITY_URI = BASE_URI + 'entity/'
  TERM_URI = BASE_URI + 'term/'

  def Sesame.initialize(dir)
    Dir.mkdir dir if not Dir.exists? dir
    java_file = java.io.File.new(dir)
    store = NativeStore.new(java_file)
    repo = SailRepository.new(store);
    repo.java_send :initialize
    repo
  end

  def Sesame.load(repo, f)
    fmt = Rio.get_parser_format_for_file_name(f)
    raise ArgumentError, "Format unknown for #{f}" unless fmt
    File.open(f, "r") do |file|
      parser = Rio.create_parser(fmt)
      parser.rdf_handler = Handler.new(repo)
      parser.parse(file.to_inputstream, ENTITY_URI)
    end
  end

  class Handler
    include org.openrdf.rio.RDFHandler

    def initialize(repo)
      @connection = repo.get_connection
    end

    def handle_statement(statement)
      @connection.add(statement)
      @chunk += 1
      if @chunk % 50000 == 0 then
        @connection.commit
        @connection.begin
      end
    end

    def start_rdf 
      @chunk = 0
      @connection.begin
    end
    def handle_namespace(prefix, uri) ;end
    def handle_comment(comment) ;end
    def end_rdf 
      @connection.commit if @chunk > 0
    end
  end
end
