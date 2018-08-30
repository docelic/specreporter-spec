module Spec

  # Total assertions counter.
  # TODO Put this in the proper place, not as class variables in Spec
  @@assertions = 0
  def self.assertions(v) @@assertions+= v end
  def self.assertions; @@assertions end

  # ditto
  @@skip_errors_report = true
  @@skip_slowest_report = false
  @@skip_failed_report = false
  def self.skip_errors_report=(v) @@skip_errors_report=v end
  def self.skip_errors_report; @@skip_errors_report end
  def self.skip_slowest_report=(v) @@skip_slowest_report=v end
  def self.skip_slowest_report; @@skip_slowest_report end
  def self.skip_failed_report=(v) @@skip_failed_report=v end
  def self.skip_failed_report; @@skip_failed_report end

  # This code should be kept to roughly follow VerboseFormatter from
  # Crystal's src/spec/formatter.cr
  class SpecReporterFormatter < Formatter

    # Indent string
    @@indent_string = "  "

    # Mapping of Crystal Spec statuses to shorter/more readable titles.
    @status= {
      success: :PASS,
      fail:    :FAIL,
      error:   :ERROR,
      pending: :PEND,
    }

    @description_width : Int32
    class Item

      def initialize(@indent : Int32, @description : String)
        @printed = false
      end

      def print(io)
        return if @printed
        @printed = true

        VerboseFormatter.print_indent(io, @indent)
        io.puts @description
      end
    end

    def initialize(indent_string = "  ", @width = 78, @elapsed_width = 3, @status_width = 5,
                   skip_errors_report = true, skip_slowest_report = true, skip_failed_report = true,
                   @trim_exceptions = true, @io : IO = STDOUT)
      @indent = 0 # Current level of indent
      @@indent_string = indent_string
      @last_description = ""
      @description_width = @width - @status_width - @elapsed_width - 7
      @items = [] of Item
      Spec.skip_errors_report = skip_errors_report
      Spec.skip_slowest_report = skip_slowest_report
      Spec.skip_failed_report = skip_failed_report
    end

    def push(context)
      @items << Item.new(@indent, context.description)
      @indent += 1
    end

    def pop
      @items.pop
      @indent -= 1
    end

    def print_indent
      self.class.print_indent(@io, @indent)
    end

    def self.print_indent(io, indent)
      #indent.times { io << make_indent(indent) }
      io << make_indent(indent)
    end

    def make_indent
      self.class.make_indent(@indent)
    end

    def self.make_indent(indent)
      @@indent_string * indent
    end

    def before_example(description)
      @items.each &.print(@io)
      print_indent
      #print description
      @io << description
      @last_description = description
    end

    def report(result)
      unless elapsed= result.elapsed; raise "Missing elapsed data" end
      @io << '\r'
      indent = make_indent
      desc_width = @description_width - indent.size
      elapsed= elapsed.total_seconds.round(@elapsed_width)
      status= "%#{@status_width}s" % @status[result.kind] || result.kind
      @io << "%s%-#{desc_width}s %s (%.#{@elapsed_width}fs)" % [
        indent,
          @last_description[0,desc_width],
          Spec.color( status, result.kind),
          elapsed
      ]
      @io.puts
      if e= result.exception
        if @trim_exceptions
          @io.puts Spec.color( "#<#{e.class}: @message=#{e.message.inspect}, @cause=#{e.cause.inspect}, @callstack=...>", result.kind)
        else
          @io.puts Spec.color( e.inspect, result.kind)
        end
      end
    end

  end

  # This extension is here to keep track of how many assertions were ran.
  module ObjectExtensions
    def should(expectation, file = __FILE__, line = __LINE__)
      Spec.assertions(1)
      unless expectation.match self
        fail(expectation.failure_message(self), file, line)
      end
    end

    def should_not(expectation, file = __FILE__, line = __LINE__)
      Spec.assertions(1)
      if expectation.match self
        fail(expectation.negative_failure_message(self), file, line)
      end
    end
  end

  # RootContext#print_results() is overriden to remove some of the content
  # from the default output. The code is otherwise mostly a copy-paste from
  # Crystal 0.23 source. If it causes an error in later versions of Crystal,
  # simply remove the whole class.
  class RootContext < Context
    def print_results(elapsed_time, aborted)
      Spec.formatters.each(&.finish)

      pendings = @results[:pending]
      unless pendings.empty?
        puts
        puts "Pending:"
        pendings.each do |pending|
          puts Spec.color("  #{pending.description}", :pending)
        end
      end

      failures = @results[:fail]
      errors = @results[:error]

      failures_and_errors = failures + errors
      if !failures_and_errors.empty? && !Spec.skip_errors_report
        puts
        puts "Failures:"
        failures_and_errors.each_with_index do |fail, i|
          if ex = fail.exception
            puts
            puts "#{(i + 1).to_s.rjust(3, ' ')}) #{fail.description}"

            if ex.is_a?(AssertionFailed)
              source_line = Spec.read_line(ex.file, ex.line)
              if source_line
                puts Spec.color("     Failure/Error: #{source_line.strip}", :error)
              end
            end
            puts

            ex.to_s.split("\n").each do |line|
              print "       "
              puts Spec.color(line, :error)
            end
            unless ex.is_a?(AssertionFailed)
              ex.backtrace.each do |trace|
                print "       "
                puts Spec.color(trace, :error)
              end
            end

            if ex.is_a?(AssertionFailed)
              puts
              puts Spec.color("     # #{Spec.relative_file(ex.file)}:#{ex.line}", :comment)
            end
          end
        end
      end

      if Spec.slowest && !Spec.skip_slowest_report
        puts
        results = @results[:success] + @results[:fail]
        top_n = results.sort_by { |res| -res.elapsed.not_nil!.to_f }[0..Spec.slowest.not_nil!]
        top_n_time = top_n.sum &.elapsed.not_nil!.total_seconds
        percent = (top_n_time * 100) / elapsed_time.total_seconds
        puts "Top #{Spec.slowest} slowest examples (#{top_n_time} seconds, #{percent.round(2)}% of total time):"
        top_n.each do |res|
          puts "  #{res.description}"
          res_elapsed = res.elapsed.not_nil!.total_seconds.to_s
          if Spec.use_colors?
            res_elapsed = res_elapsed.colorize.bold
          end
          puts "    #{res_elapsed} seconds #{Spec.relative_file(res.file)}:#{res.line}"
        end
      end

      puts

      success = @results[:success]
      total = pendings.size + failures.size + errors.size + success.size

      final_status = case
                     when (failures.size + errors.size) > 0 then :fail
                     when pendings.size > 0                 then :pending
                     else                                        :success
                     end

      puts "Finished in #{Spec.to_human(elapsed_time)}"
      puts Spec.color("#{total} examples, #{Spec.assertions} assertions, #{failures.size} failures, #{errors.size} errors, #{pendings.size} pending", final_status)

      if !failures_and_errors.empty? && !Spec.skip_failed_report
        puts
        puts "Failed examples:"
        puts
        failures_and_errors.each do |fail|
          print Spec.color("crystal spec #{Spec.relative_file(fail.file)}:#{fail.line}", :error)
          puts Spec.color(" # #{fail.description}", :comment)
        end
      end
    end
  end
end
