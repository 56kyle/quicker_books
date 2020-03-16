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

    attr_accessor :part_children, :part_parent, :part_parent_name, :part_path, :part, :part_name

    def make_directories_from(input= 'QBXML')
      @q = Qbxml.new(:qb, '13.0')
      @tabs = 0
      starting_qbxml = @q.describe(input)
      starting_qbxml.traverse do |part|
        make_dir(part) unless part.name.to_s.include?('()') || part.name.to_s == 'text' || part.name.to_s == 'comment'
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
          part_path_adjusted = @part_path[0, @part_path.size - 1]
          part_path_adjusted.each do |a_parent|
            line "module #{a_parent.camelize}Module"
            @tabs+=1
          end
          yield
          part_path_adjusted.each do
            @tabs-=1
            line "end"
          end
        end
        @lines
      end

      def line(the_line = nil)
        @lines << tabs + the_line if the_line
        yield if block_given?
        @lines
      end

      def rq
        a_file do
          base_entity do
            a_method 'requests', %w(job session data) do
              requests_content
            end
          end
        end
      end

      def rs
        a_file do
          base_entity do
            a_method 'handle_response', %w(response session job requests data) do
              handle_response_content
            end
          end
        end
      end

      def struct_base
        a_file do
          base_entity do
            a_method 'requests', %w(job session data) do
              requests_content
            end
            a_method 'handle_response', %w(response session job requests data) do
              handle_response_content
            end
          end
        end
      end


      def base_entity
        a_method @part_name.underscore do
          line "#{@part_parent_name}Module::#{@part_name}.new"
        end
        a_class @part_name, @part_parent_name do
          line "attr_accessor :required"
          a_method 'initialize' do
            initializer_content
          end
          yield if block_given?
        end
      end

      def initializer_content
        line "@required = #{@required.to_s}"
        line "self.class.include #{@part_name}Module unless #{@part_name}.include?(#{@part_name}Module)" if @part_children.present?
      end

      def requests_content
        if @part_children && @part_children.present?
          line '{'
          @tabs+=2
          line ":#{@part_name.underscore} => {"
          @tabs+=1
          the_last_name = @part_children.last.name.camelize
          @part_children.map{|c| c.name.camelize }.each do |c_name|
            line ":#{c_name} => #{c_name.underscore}.requests(job, session, data)#{',' unless the_last_name == c_name}"
          end
          @tabs-=1
          line '}'
          @tabs-=2
          line '}'
        end
      end

      def handle_response_content
        line "block_given? ? super{yield['#{@part.name}']} : super{response['#{@part.name}']}"
      end

      def find_required_parts
        @required = []
        @part.children.each do |c|
          c.content.scan(/(?:BEGIN OR:.*have )(.*)/).map do |one_of_this_array|
            @required << one_of_this_array[0].gsub('OR', '||') if one_of_this_array.present?
          end
        end
      end

      def find_children(part)
        part.children.select{|c|c.name != 'text' && c.name != 'comment'}
      end

      def module_exists?(name, base = self.class)
        base.const_defined?(name) &&
            base.const_get(name).instance_of?(::Module)
      end

      def make_dir(instance_start)
        part = instance_start
        @part = part
        @part_name = part.name.camelize
        @part_path = part.path&.split('/')[1,100]
        @part_parent = part.parent
        @part_parent_name = @part_parent&.name.camelize
        @part_children = find_children(part)
        @required = []
        #empty_directory('./app/'+@part_path.join('Module/').underscore) if @part_children
        template('./struct.erb', './app/'+@part_path.join('Module/').underscore+'.rb')
      end
    end
  end
end

