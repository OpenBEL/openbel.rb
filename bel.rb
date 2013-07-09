# vim: ts=2 sw=2:
raise "JRuby required" unless (RUBY_PLATFORM =~ /java/)

require 'addressable/uri'
require 'libs/antlr4-runtime-4.0.1-SNAPSHOT.jar'
require 'libs/openbel-common.jar'
require_relative 'sesame'
import org.openbel.bel.model.Namespace
import org.openbel.bel.model.Parameter
import org.openbel.bel.model.Statement
import org.openbel.bel.model.Term
import org.openbel.bel.parser.Parser
import org.openbel.bel.parser.ParseListener
import org.openrdf.query.QueryLanguage
import org.openrdf.model.vocabulary.SKOS
import org.openrdf.model.vocabulary.RDF
import org.openrdf.model.vocabulary.RDFS

# TODO Initialize BEL with repository
module BEL

  EG_NS = Namespace.new('EGID', '')

  def BEL.add_statement_string(bel_statement, annotations, citation, repo)
    stmt = self.parse(bel_statement)
    return self.add_statement(stmt, annotations, citation, repo)
  end

  def BEL.add_statement(stmt, annotations, citation, repo)
    vft = repo.value_factory
    cxn = repo.connection
    cxn.begin
    begin
      case
        # subject-only statement
        when stmt.relationship_type == nil
          subject_uri = add_term(stmt.subject, vft, cxn)
          predicate_uri = vft.create_uri(Sesame::TYPE_URI + 'empty')
          object_uri = vft.create_uri(Sesame::TYPE_URI + 'empty')
        # simple statement
        when stmt.object.term != nil
          subject_uri = add_term(stmt.subject, vft, cxn)
          predicate_uri = Sesame::TYPE_URI +
                          stmt.relationship_type.display_value
          object_uri = add_term(stmt.object.term, vft, cxn)
        # nested statement
        else
          return nil
        end
        bn_stmt = vft.create_bnode
        cxn.add(bn_stmt, RDF::TYPE, RDF::STATEMENT)
        cxn.add(bn_stmt, RDF::SUBJECT, subject_uri)
        cxn.add(bn_stmt, RDF::PREDICATE, vft.create_uri(predicate_uri))
        cxn.add(bn_stmt, RDF::OBJECT, object_uri)
        bn_stmt
    ensure
      cxn.commit
      cxn.close
    end
  end

  def BEL.create_document(name, repo)
    vft = repo.value_factory
    cxn = repo.connection
    cxn.begin
    begin
      bn_stmt = vft.create_bnode(name)
      document_uri = vft.create_uri(Sesame::TYPE_URI + 'Document')
      cxn.add(bn_stmt, RDF::TYPE, document_uri)
      document_uri
    ensure
      cxn.commit
      cxn.close
    end
  end

  def BEL.add_document(document_uri, file_path, compressed, repo)
    File.open(file_path, 'r:UTF-8') do |f|
      is = f.to_inputstream
      if compressed then
        # FIXME Zlib:: -> GzipReader.new, GzipReader.open, GzipFile.wrap
        gz = java.util.zip.GZIPInputStream.new(is)
        DocumentParser.new(gz, repo).parse()
      else
        DocumentParser.new(is, repo).parse()
      end
    end
  end

  private

  def BEL.add_term(term, vft, cxn)
    c_term = self.canonicalize(term, cxn)
    c_bel = c_term.to_bel_short_form
    
    term_uri = vft.create_uri(Sesame::TERM_URI + c_bel)
    fun_type_uri = vft.create_uri(
      Sesame::TYPE_URI + term.function_enum.display_value)
    cxn.add(term_uri, RDF::TYPE, fun_type_uri)
    cxn.add(term_uri, RDFS::LABEL, vft.create_literal(c_bel))
    c_term.all_parameters.each do |p|
      if p.namespace then
        p_uri = vft.create_uri(
          Sesame::ENTITY_URI + p.namespace.prefix + '/' + p.value)
        cxn.add(term_uri, vft.create_uri(Sesame::HAS_PARAM), p_uri)
      end
    end
    term_uri
  end

  def BEL.parse(bel_statement)
    helper = ParseHelper.new()
    Parser.parse_statement(bel_statement, helper)
    helper.parsed_statement
  end

  def BEL.canonicalize(term, cxn)
    new_term = Term.new(term.function_enum)
    term.function_arguments.each do |arg|
      case
      when arg.kind_of?(Term)
        arg_term = self.canonicalize(arg, cxn)
        new_term.add_function_argument(arg_term)
      when arg.kind_of?(Parameter)
        arg_param = self.equivalence(arg, EG_NS, cxn) || arg
        new_term.add_function_argument(arg_param)
      end
    end
    new_term
  end

  def BEL.equivalence(param, target_ns, cxn)
    return param if not param.namespace
    param_uri = Addressable::URI.encode(Sesame::ENTITY_URI +
                                        param.namespace.prefix + '/' +
                                        param.value)
    target_ns_uri = Sesame::ENTITY_URI + target_ns.prefix
    qs = %Q(
      SELECT ?lbl
      WHERE {
        <#{param_uri}> <#{SKOS::EXACT_MATCH}> ?o .
        ?o <#{SKOS::IN_SCHEME}> <#{target_ns_uri}> .
        ?o <#{SKOS::PREF_LABEL}> ?lbl .
      }
    )
    query = cxn.prepare_tuple_query(QueryLanguage::SPARQL, qs)
    result = query.evaluate
    begin
      if result.has_next then
        binding = result.next
        value = binding.get_value('lbl').string_value
        return Parameter.new(EG_NS, value)
      end
    ensure
      result.close
    end
  end

  class DocumentParser
    include org.openbel.bel.parser.ParseListener

    BUFFER_BYTES = 1_000_000

    def initialize(is, repo)
      @input_stream = is
      @repo = repo
      @cxn = @repo.connection
      @vft = @repo.value_factory
    end

    def parse
      Parser.parse(@input_stream, self, BUFFER_BYTES)
    end

    def enterdoc
      @cxn.begin
      @chunk = 0
    end

    def exitdoc
      if @chunk > 0 then
        @cxn.commit
      end
      @cxn.close
    end

    def parameter(param)
    end

    def term(term)
    end

    def statement(stmt)
      case
        # subject-only statement
        when stmt.relationship_type == nil
          subject_uri = BEL.add_term(stmt.subject, @vft, @cxn)
          predicate_uri = Sesame::TYPE_URI + 'empty'
          object_uri = @vft.create_uri(Sesame::TYPE_URI + 'empty')
        # simple statement
        when stmt.object.term != nil
          subject_uri = BEL.add_term(stmt.subject, @vft, @cxn)
          predicate_uri = Sesame::TYPE_URI +
                          stmt.relationship_type.display_value
          object_uri = BEL.add_term(stmt.object.term, @vft, @cxn)
        else
          return
        end
      bn_stmt = @vft.create_bnode
      @cxn.add(bn_stmt, RDF::TYPE, RDF::STATEMENT)
      @cxn.add(bn_stmt, RDF::SUBJECT, subject_uri)
      @cxn.add(bn_stmt, RDF::PREDICATE, @vft.create_uri(predicate_uri))
      @cxn.add(bn_stmt, RDF::OBJECT, object_uri)

      @chunk += 1
      if @chunk == 10 then
        @chunk = 0
        @cxn.commit
        @cxn.begin
      end
    end
  end

  class ParseHelper
    include org.openbel.bel.parser.ParseListener

    attr_reader :parsed_parameter
    attr_reader :parsed_term
    attr_reader :parsed_statement

    def annotation(annotation_def, annotation)
    end

    def docproperty(name, value)
    end

    def parameter(param)
      @parsed_parameter = param
    end

    def term(term)
      @parsed_term = term
    end

    def statement(statement)
      @parsed_statement = statement
    end
  end
end
