args = ["-f", "input.txt", "--stuff", "hello", "world", "test", "--debug"]

macro cli(opts)
  # This will hold our option names
  {% options = [] of String %}

  # Lets go for all options we have
  {% for receiver, block in opts %}
       # Each opt is receiver.>>{ |block.args| block.body }

       # Receiver looks like: "-short --long"
       {% short = receiver.split.first %}
       {% short_name = short[1..-1] %}
       {% long = receiver.split.last %}
       {% long_name = long[2..-1] %}

       # Extract args, args size and body from block
       {% if block.receiver.is_a?(ArrayLiteral) %}
         # of form `[a, b, c].> { ... }` - there are arguments
         {% args = block.receiver %}
         {% arg_size = args.length %}
         {% block_body = block.block.body %}
       {% else %}
         # of form `0.> { ... }` - there are no arguments
         {% args = [] of String %}
         {% arg_size = 0 %}
         {% block_body = block.block.body %}
       {% end %}

       # Register option into our list of options
       {% options << long_name %}

       # Answers if argument is start of this option
       def __clik_handles_{{long_name.id}}(opt)
         opt == {{short}} || opt == {{long}}
       end

       # Executes provided block for this option and arguments
       def __clik_call_{{long_name.id}}({{args.argify}})
         {{block_body}}
       end

       # This helper does the following:
       # - read necessary amount of options from argument list
       # - build up a Tuple out of them, so that it can be splatted
       def __clik_read_{{long_name.id}}(args, i)
         {% if arg_size > 0 %}
           {
             {% for j in (0...arg_size) %}
                  args[i + {{j}}],
             {% end %}
           }
         {% else %}
           Tuple.new
         {% end %}
       end
  {% end %}

  # Our main parse function, accepts argument list
  %i = 0
  %n = args.size

  # Lets go through the whole list
  while %i < %n
    # Fetch current option
    opt = args[%i]

    # For each registered option
    {% for long in options %}
         # Ask handler if it recognises current argument as itself
         if __clik_handles_{{long.id}}(opt)
           # Get the tuple from args, starting from next argument
           %arg_tuple = __clik_read_{{long.id}}(args, %i + 1)

           # Advance iterator by size of arguments that were read
           # and +1 for current option itself
           %i += %arg_tuple.size + 1

           # Call handler for this option
           __clik_call_{{long.id}}(*%arg_tuple)

           # Skip to next iteration of loop
           next
         end
    {% end %}

    # Fail if current option is unknown
    # This could break and return all arguments
    # that are left, as "free" arguments;
    # `return args[i..-1]` or something like that
    raise "option #{opt} is unsupported"
  end
end

def show_help
  puts "Help"
end

cli({"-f --file"  => [f].> { @@file = f },
     "-s --stuff" => [a, b, c].> { pp({a, b, c}) },
     "-d --debug" => 0.> { $DEBUG = true },
     "-h --help"  => 0.> { show_help }})

pp @@file
pp $DEBUG
