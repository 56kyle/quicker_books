require "quicker_books/engine"
require 'thor'
require 'qbxml'

module QuickerBooks
  class CreateAll < Thor
    include Thor::Actions
    desc 'idk', 'Makes a whole lot of things.'
    puts self.source_paths
    source_root File.expand_path('../quicker_books/templates', __FILE__)

    attr_accessor :part_children, :part_parent, :part_path, :part

    def make_directories_from(input= 'QBXMLMsgsRq')
      @q = Qbxml.new(:qb, '13.0')
      starting_qbxml = @q.describe(input)
      starting_qbxml.traverse do |part|
        make_dir(part) unless part.name.to_s.include?('()') || part.name.to_s == 'text' || part.name.to_s == 'comment'
      end
      @head = starting_qbxml
      template('qb_map.erb', './app/jobs/qb_map.rb')
    end


    no_commands do
      def tabs
        result = ""
        @tabs.times do
          result << "\t"
        end
        result
      end
      def make_module_parents(head= nil)
        if head
          @part = head
        end
        @part_path = @part.path.split('/')[1,100]
      end
      def make_dir(instance_start)
        part = instance_start
        @part = part
        @part_path = part.path.split('/')[1,100]
        @part_parent = part.parent
        @part_children = find_children(part)
        empty_directory('./app/jobs/' + @part_path.join('/')) if @part_children.present?
        @part_children.present? ? template('struct.erb', './app/jobs/'+@part_path.join('/')+'.rb') : template('end.erb', './app/jobs/'+@part_path.join('/')+'.rb')
      end
      def find_children(part)
        part.children.select{|c|c.name != 'text' && c.name != 'comment'}
      end
      def child_class(c)
        c_name = c.name.camelize
        p_name = c.parent.name.camelize
        c_kids = find_children(c)
        puts c.children.select{|cc| cc.name == 'comment'}.map{|cc|cc.content}.join('~!~').scan(/(Begin OR)(?:.*\n*)*?(OR.*\n*?)+(?:.*\n*?)*?(End OR)/)
        [
            "class #{c_name}",
            "  def initialize",
            "    if block_given?",
            "      super do",
            "        { #{c_name.underscore}: yield }",
            "      end",
            "    else",
            "      nil",
            "    end",
            "  end",
            "end"
        ].compact.join("\n#{tabs}")
      end
      def new_kids(part)
        if find_children(part).present?
          find_children(part).map do |c|
            "  def #{c.name.underscore}; #{c.name.camelize}.new end"
          end.join("\n#{tabs}")
        else
          nil
        end
      end
    end
  end
end

