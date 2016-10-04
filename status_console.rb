require 'io/console'
require 'io/console/size'

class StatusConsole

  attr_reader :width, :height, :status_line
  attr_accessor :wrap_width

  def initialize
    h, w = IO.console_size
    @width = w
    @height = h
    @log_lines = []
    @status_line = ''
    self.wrap_width = 79
  end

  def paint
    last_log_line = @log_lines.count - ((@log_lines.count > 0 && @log_lines.last === true) ? 2 : 1)
    log_line_count = height - 3
    display_lines =
        if last_log_line < 0
          []
        elsif last_log_line == 0
          [ @log_lines[0] ]
        else
          first_log_line = last_log_line - log_line_count + 1
          first_log_line = 0 if first_log_line < 0
          @log_lines[first_log_line..last_log_line] || []
        end

    display_lines << '' while display_lines.count < log_line_count

    # just in case we have too many for some reason...
    display_lines.delete_at(0) while display_lines.count >= log_line_count

    # add a blank and then the status line.
    display_lines <<  ''
    display_lines << status_line

    display_lines.each_with_index do |line,index|
      row = index + 1
      last_line = (row == display_lines.count)
      line_color = last_line ? ';33;1;40' : ''
      pad_length = width - line.length - (last_line ? 1 : 0)
      print "\033[#{row};1H\033[0#{line_color}m#{line}#{' ' * pad_length}\033[0m"
    end

    # move to row right above the last row to simulate continuity in the log messages.
    print "\033[#{height - 1};1H"

  end

  def status_line=(value)
    @status_line = value.to_s
    paint
  end

  def append_data(data)
    ends_with_nl = data[-1] == "\n"
    data_lines = data.split("\n")
    @log_lines ||= []

    temp_log_line =
        if @log_lines.count <= 0
          ''
        elsif @log_lines.last === true
          @log_lines.delete_at(@log_lines.count - 1)
          ''
        else
          @log_lines.delete_at(@log_lines.count - 1)
        end

    data_lines.each do |data_line|
      temp_log_line += data_line
      if wrap_width > 0 && temp_log_line.length > wrap_width
        until temp_log_line == ''
          @log_lines << temp_log_line[0...wrap_width].to_s
          temp_log_line = temp_log_line[wrap_width..-1].to_s
        end
      else
        @log_lines << temp_log_line
      end
      temp_log_line = ''
    end

    while @log_lines.count > 1000
      @log_lines.delete_at 0
    end

    @log_lines << true if ends_with_nl

    paint
  end

end