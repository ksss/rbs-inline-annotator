module RBS::Inline::Annotator
  class Visitor < Prism::Visitor
    def initialize(env:, result:)
      @env = env
      @result = result
      @stack = []
      @kind = :instance
      super()
    end

    def insert_before(range, text)
      @result.writer.insert_before(range:, text:)
    end

    def insert_after(range, text)
      @result.writer.insert_after(range:, text:)
    end

    def replace(range, text)
      @result.writer.replace(range:, text:)
    end

    def remove(range)
      replace(range, "")
    end

    def node_range(node)
      Range.new(
        node.location.start_character_offset,
        node.location.end_character_offset,
      )
    end

    def visit_singleton_class_node(node)
      if @kind == :singleton
        warn "nested singleton class detected"
        return
      end

      @kind = :singleton
      visit_child_nodes(node)
    ensure
      @kind = :instance
    end

    def module_class_entry
      @env.module_class_entry(type_name)
    end

    def visit_class_node(node)
      push_type_name(node) do
        with_superclass(node.superclass)
        # TODO: Which file should we write to?
        # with_embedding_rbs(header_node(node), node)
        # with_variables(header_node(node), node)
        visit_child_nodes(node)
      end
    end

    def visit_module_node(node)
      push_type_name(node) do
        with_module_self(node)
        # TODO: Which file should we write to?
        # with_embedding_rbs(header_node(node), node)
        # with_variables(header_node(node), node)
        visit_child_nodes(node)
      end
    end

    def header_node(node)
      case node
      when Prism::ClassNode
        node.superclass ? node.superclass : node.constant_path
      when Prism::ModuleNode
        node.constant_path
      end
    end

    def with_embedding_rbs(header_node, node)
      entry = module_class_entry or return
      indent = " " * (node.body ? node.body.location.start_column : node.location.start_column + 2)
      embedding_rbs = []
      entry.each_decl do |decl|
        decl.members.each do |member|
          case member
          when RBS::AST::Declarations::Interface, RBS::AST::Declarations::TypeAlias
            embedding_rbs << member
          end
        end
      end

      if embedding_rbs.any?
        header_range = node_range(header_node)
        insert_after(header_range, "\n#{indent}# @rbs!\n")
        embedding_rbs.each do |member|
          case member
          when RBS::AST::Declarations::Interface
            insert_after(header_range, "#{indent}#   interface #{member.name}\n")
            member.members.each do |m|
              insert_after(header_range, "#{indent}#     #{m.location.source.strip}\n")
            end
            insert_after(header_range, "#{indent}#   end\n")
          when RBS::AST::Declarations::TypeAlias
            insert_after(header_range, "#{indent}#   type #{member.name} = #{member.type}\n")
          end
        end
      end
    end

    def with_superclass(node)
      node or return
      entry = module_class_entry or return
      super_class_decl = entry.primary_decl.super_class or return
      return unless super_class_decl.args.any?

      args = super_class_decl.args.join(", ")
      insert_after(node_range(node), " #[#{args}]")
    end

    def with_variables(header_node, node)
      indent = " " * (node.body ? node.body.location.start_column : node.location.start_column + 2)
      entry = module_class_entry or return
      added = false
      entry.each_decl do |decl|
        decl.members.each do |member|
          case member
          when RBS::AST::Members::InstanceVariable
            insert_after(node_range(header_node), "\n#{indent}# @rbs #{member.name}: #{member.type}")
            added = true
          when RBS::AST::Members::ClassVariable
            insert_after(node_range(header_node), "\n#{indent}# @rbs #{member.name}: #{member.type}")
            added = true
          when RBS::AST::Members::ClassInstanceVariable
            insert_after(node_range(header_node), "\n#{indent}# @rbs #{member.name}: #{member.type}")
            added = true
          end
        end
      end
      if added && node.body&.body&.first
        insert_before(node_range(node.body.body.first), "\n#{indent}")
      end
    end

    def with_module_self(node)
      entry = module_class_entry or return
      self_types = entry.primary_decl.self_types
      if self_types.any?
        indent = " " * node.location.start_column
        insert_before(node_range(node), "# @rbs module-self #{self_types.join(", ")}\n#{indent}")
      end
    end

    def visit_def_node(node)
      module_class_entry&.each_decl do |decl|
        decl.members.each do |member|
          case member
          when RBS::AST::Members::MethodDefinition
            next unless node.name == member.name

            if node.receiver.nil? && @kind == :instance
              # def foo
              next unless member.instance?
            elsif node.receiver.is_a?(Prism::SelfNode) || @kind == :singleton
              # def self.foo
              next unless member.singleton?
            else
              next
            end

            add_rbs_inline_annotation_for_def_node(node:, method_definition: member)
          end
        end
      end
    end

    def add_rbs_inline_annotation_for_def_node(node:, method_definition:)
      indent = " " * node.location.start_column

      if method_definition.annotations.any?
        method_definition.annotations.each do |a|
          insert_before(node_range(node), "# @rbs %a{#{a.string}}\n#{indent}")
        end
      end

      if method_definition.overloading
        insert_before(node_range(node), "# @rbs overload\n#{indent}")
        return
      end

      if method_definition.overloads.length > 1
        # multiple overloads
        method_definition.overloads.each_with_index do |overload, index|
          text = if index == 0
                   "# @rbs #{overload.method_type}\n#{indent}"
                 else
                   "#    | #{overload.method_type}\n#{indent}"
                 end

          insert_before(node_range(node), text)
        end
      else
        overload = method_definition.overloads.first
        method_type = overload.method_type
        func = method_type.type
        indent = " " * node.location.start_column
        new_annotation = lambda { |name, type|
          insert_before(node_range(node), "# @rbs #{name}: #{type}\n#{indent}")
        }
        for_positional_params = lambda { |orig_sig, orig_ruby|
          sig = orig_sig.dup or break
          ruby = orig_ruby.dup or break
          sig.each do |rbs|
            rb = ruby.shift
            if rbs.name
              name = rbs.name
            else
              if rb.nil?
                s = (node.receiver.is_a?(Prism::SelfNode) || @kind == :singleton) ? "." : "#"
                warn "Parameter mismatch #{type_name}#{s}#{node.name}"
                break
              end
              name = rb.name
            end

            type = rbs.type.to_s
            next if type == "untyped"

            new_annotation.call(name, type)
          end
        }
        for_keyword_params = lambda { |orig_sig, _orig_ruby|
          sig = orig_sig.dup or break
          # ruby = orig_ruby.dup or break
          sig.each do |name, param|
            type = param.type.to_s
            next if type == "untyped"

            new_annotation.call(name, type)
          end
        }
        for_rest_param = lambda { |prefix, sig, ruby|
          name = sig.name || ruby.name
          type = sig.type.to_s
          next if type == "untyped"

          new_annotation.call("#{prefix}#{name}", type)
        }
        for_return_param = lambda { |return_type|
          return_type = return_type.to_s
          break if return_type == "untyped"

          new_annotation.call("return", return_type)
        }
        if node.parameters
          case func
          when RBS::Types::UntypedFunction
            # do nothing
          when RBS::Types::Function
            for_positional_params.call(func.required_positionals, node.parameters.requireds)
            for_positional_params.call(func.optional_positionals, node.parameters.optionals)
            for_rest_param.call("*", func.rest_positionals, node.parameters.rest) if func.rest_positionals
            for_positional_params.call(func.trailing_positionals, node.parameters.posts) if func.trailing_positionals
            for_keyword_params.call(func.required_keywords, node.parameters.keywords.grep(Prism::RequiredKeywordParameterNode))
            for_keyword_params.call(func.optional_keywords, node.parameters.keywords.grep(Prism::OptionalKeywordParameterNode))
            for_rest_param.call("**", func.rest_keywords, node.parameters.keyword_rest) if func.rest_keywords
          end
        end
        if method_type.block
          name = node.parameters&.block&.name
          block_source = method_type.block.location.source
          # "?{ (Integer) -> Integer } -> void"
          # -> "? (Integer) -> Integer"
          block_source = block_source.gsub(/[{}]/, "").strip
          new_annotation.call("&#{name}", block_source)
        end
        for_return_param.call(func.return_type)
      end
    end

    def visit_call_node(node)
      return if @stack.empty?

      case node.name
      when :attr_reader, :attr_writer, :attr_accessor
        when_attribute_node(node)
      when :include, :extend, :prepend
        when_mixin_node(node)
      end
    end

    def when_attribute_node(node)
      case node.receiver
      when nil, Prism::SelfNode
        if node.arguments.arguments.length == 1
          first_arg_node = node.arguments.arguments.first
          return unless first_arg_node.is_a?(Prism::SymbolNode)

          value = first_arg_node.value
          module_class_entry&.each_decl do |decl|
            decl.members.each do |member|
              next unless (node.name == :attr_reader && member.is_a?(RBS::AST::Members::AttrReader)) ||
                          (node.name == :attr_writer && member.is_a?(RBS::AST::Members::AttrWriter)) ||
                          (node.name == :attr_accessor && member.is_a?(RBS::AST::Members::AttrAccessor))
              next unless member.name == value.to_sym

              type = member.type.to_s
              next if type == "untyped"

              insert_after(node_range(node), " #: #{type}")
            end
          end
        else
          replaced_count = 0
          node.arguments.arguments.each do |arg|
            next unless arg.is_a?(Prism::SymbolNode)

            value = arg.value
            module_class_entry&.each_decl do |decl|
              decl.members.each do |member|
                next unless (node.name == :attr_reader && member.is_a?(RBS::AST::Members::AttrReader)) ||
                            (node.name == :attr_writer && member.is_a?(RBS::AST::Members::AttrWriter)) ||
                            (node.name == :attr_accessor && member.is_a?(RBS::AST::Members::AttrAccessor))
                next unless member.name == value.to_sym

                indent = replaced_count == 0 ? "" : " " * node.location.start_column
                insert_before(node_range(node), "#{indent}#{node.name} :#{value} #: #{member.type}\n")
                replaced_count += 1
              end
            end
          end

          if replaced_count == node.arguments.arguments.length
            range = node_range(node)
            # Remove attr_*
            remove(range)
            # Remove the last newline
            remove(Range.new(range.end, range.end + 1))
          end
        end
      end
    end

    def when_mixin_node(node)
      case node.receiver
      when nil, Prism::SelfNode
        if node.arguments.arguments.length == 1
          first_arg_node = node.arguments.arguments.first
          return unless first_arg_node.is_a?(Prism::ConstantReadNode)

          name = first_arg_node.name
          module_class_entry&.each_decl do |decl|
            decl.members.each do |member|
              next unless (node.name == :include && member.is_a?(RBS::AST::Members::Include)) ||
                          (node.name == :extend && member.is_a?(RBS::AST::Members::Extend)) ||
                          (node.name == :prepend && member.is_a?(RBS::AST::Members::Prepend))
              next unless member.name.to_s == name.to_s
              next unless member.args.any?

              type = member.args.join(", ")
              insert_after(node_range(node), " #[#{type}]")
            end
          end
        else
          replaced_count = 0
          node.arguments.arguments.each do |arg|
            next unless arg.is_a?(Prism::ConstantReadNode)

            name = arg.name
            module_class_entry&.each_decl do |decl|
              decl.members.each do |member|
                next unless (node.name == :include && member.is_a?(RBS::AST::Members::Include)) ||
                            (node.name == :extend && member.is_a?(RBS::AST::Members::Extend)) ||
                            (node.name == :prepend && member.is_a?(RBS::AST::Members::Prepend))
                next unless member.name.to_s == name.to_s
                next unless member.args.any?

                indent = replaced_count == 0 ? "" : " " * node.location.start_column
                insert_before(node_range(node), "#{indent}#{node.name} #{name} #[#{member.args.join(", ")}]\n")
                replaced_count += 1
              end
            end
          end

          if replaced_count > 0 && replaced_count == node.arguments.arguments.length
            range = node_range(node)
            # Remove include *
            remove(range)
            # Remove the last newline
            remove(Range.new(range.end, range.end + 1))
          end
        end
      end
    end

    def visit_constant_write_node(node)
      constant_type_name = RBS::TypeName.new(
        name: node.name,
        namespace: type_name.to_namespace
      )
      entry = @env.constant_decls[constant_type_name] or return
      type = entry.decl.type.to_s
      return if type == "untyped"

      add_rbs_inline_annotation_for_trailing(node:, type:)
    end

    def add_rbs_inline_annotation_for_trailing(node:, type:)
      return if type == "untyped"

      insert_after(node_range(node), " #: #{type}")
    end

    def push_type_name(node)
      parts = node.constant_path.full_name_parts.dup
      @stack.push(parts)

      yield
    ensure
      @stack.pop
    end

    def type_name
      if @stack.empty?
        nil
      else
        absolute = false
        names = []
        @stack.reverse_each do |parts|
          names.unshift(*parts)
          if names.first == :""
            absolute = true
            names.shift
            break
          end
        end
        *path, name = names.map(&:to_sym)
        RBS::TypeName.new(
          name: name,
          namespace: RBS::Namespace.new(path:, absolute:)
        ).absolute!
      end
    end
  end
end
