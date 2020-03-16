require "quicker_books/engine"
require 'thor'
require 'qbxml'
require 'qbwc'


module QuickerBooks
  class CreateAll < Thor
    include Thor::Actions
    desc 'idk', 'Makes a whole lot of things.'
    puts self.source_paths
    source_root File.expand_path('../quicker_books/templates', __FILE__)

    attr_accessor :part_children, :part, :part_name

    def make_directories_from(input= 'QBXMLMsgsRq')
      @q = Qbxml.new(:qb, '13.0')
      @tabs = 0
      starting_qbxml = @q.describe(input)
      starting_qbxml.children.each do |c|
        make_dir(c) unless c.name.to_s.include?('()') || c.name.to_s == 'text' || c.name.to_s == 'comment'
      end
    end

    no_commands do

      def tabs
        result = ""
        @tabs.times do
          result << "\t"
        end
        result
      end

      def a_class(a_class_name= nil, super_class_name= nil)
        if a_class_name && block_given?
          line "class #{a_class_name}#{super_class_name ? ' < ' + super_class_name : nil}"
          @tabs+=1
          yield
          @tabs-=1
          line 'end'
        end
      end

      def a_method(a_method_name= nil, parameters= nil)
        if parameters.is_a?(Hash)
          parameters = parameters.map{|key, val| "#{key.to_s} = #{val}" }
        end
        if a_method_name && block_given?
          line "def #{a_method_name}#{parameters ? '(' + parameters.join(', ') + ')' : nil}"
          @tabs+=1
          yield
          @tabs-=1
          line 'end'
        end
      end

      def a_file
        @lines = []
        if block_given?
          line "module QuickerBooks"
          @tabs+=1
          yield
          @tabs-=1
          line "end"
        end
        @lines
      end

      def line(the_line = nil)
        @lines << tabs + the_line if the_line
        yield if block_given?
        @lines
      end

      def struct_base
        a_file do
          a_class @part_name, 'QBWC::Worker' do
            a_method 'initialize' do
              line 'nil'
            end
            a_method 'requests', %w(job session data) do
              requests_content
            end
            a_method 'handle_response', %w(response session job requests data) do
              line "nil"
            end
          end
        end
      end

      def requests_content
        new_hash = Hash.from_xml(@part.to_xml).deep_transform_keys do |key|
          key.to_s.underscore
        end
        new_hash.pretty_inspect.gsub("=>{", "=>\n{").gsub(", ", ",\n").split("\n").each do |hash_line|
          line hash_line
        end
      end

      def find_children(part)
        part.children.select{|c|c.name != 'text' && c.name != 'comment'}
      end

      def make_dir(instance_start)
        @part = instance_start
        @part_name = @part.name.camelize
        @part_children = find_children(part)
        template('./struct.erb', './lib/'+@part_name.underscore+'.rb')
      end
    end
  end
end

