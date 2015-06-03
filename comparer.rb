=begin
--------------------------------------------------------------------------------

Take two filenames.
For each file,
  build a array of queries, made of times and query strings.
    Note that there may be duplicate query strings.
  Get count of queries and total of times.

Compare the files
  remove common queries, noting the count removed and the time removed on each side (may be different)
    if a common query occurs multiple times, remove matching pairs irrespective of times. keep any remaining.
  get count of common, time totals for each file
  get count of unique, time totals for each file.

Dump the unique queries to two new files.

--------------------------------------------------------------------------------
The report

                total      common       unique
filename1   900  1.234   124  1.500   102 11.500
filename2  1024  6.103   124 12.105   600  4.123

outputs to report-filename1-filename2, diff-filename1-filename2 and diff-filename2-filename1

--------------------------------------------------------------------------------
=end

class UserInputError < StandardError
end

# ---------------------------------------------------------
# Utils
# ---------------------------------------------------------

module Kernel
  def warning(message)
    puts("WARNING: #{message}")
  end

  def bogus(message)
    puts(">>>>>>>>>>>>>BOGUS #{message}")
  end
end

# ---------------------------------------------------------

class Parser
  def self.parse(file)
    list = []
    File.open(file) do |f|
      f.each_line do |line|
        if /.*\[RDFServiceLogger\]\s+(\S+)\s+(.*)$/ =~ line.chomp
          list << [$2, $1.to_f]
        end
      end
    end
    list.sort{|a, b| a[0] <=> b[0]}
  end
end

# ---------------------------------------------------------

class Comparer
  def initialize(args)
    raise UserInputError.new("Usage: ruby comparer.rb filename1 filename2") unless args && args.size == 2
    raise UserInputError.new("File not found: '#{args[0]}'") unless File.exist?(args[0])
    raise UserInputError.new("File not found: '#{args[1]}'") unless File.exist?(args[1])
    @file1 = File.expand_path(args[0])
    @file2 = File.expand_path(args[1])
    @base1 = File.basename(@file1)
    @base2 = File.basename(@file2)
    @report = File.expand_path("report-#{@base1}-#{@base2}")
    @diff1 = File.expand_path("diff-#{@base1}-#{@base2}")
    @diff2 = File.expand_path("diff-#{@base2}-#{@base1}")
  end

  def parse_files()
    @list1 = Parser.parse(@file1)
    @list2 = Parser.parse(@file2)
  end

  def compare_files()
    @common_count = 0
    @common_time_1 = 0.0
    @common_time_2 = 0.0

    @unique2 = @list2[0..-1]
    @unique1 = @list1.select do |q1|
      match_index = @unique2.index{|q2| q1[0] == q2[0]}
      if match_index
        @common_count += 1
        @common_time_1 += q1[1]
        @common_time_2 += @unique2[match_index][1]
        @unique2.delete_at(match_index)
        false
      else
        true
      end
    end
  end

  def dump_remainders()
    File.open(@diff1, 'w') do |f|
      @unique1.each do |q|
        f.puts("#{q[1]} #{q[0]}")
      end
    end
    File.open(@diff2, 'w') do |f|
      @unique2.each do |q|
        f.puts("#{q[1]} #{q[0]}")
      end
    end
  end

  def sum_times(list)
    list.inject(0) { |sum, q| sum + q[1] }
  end

  def report()
    w = [@base1.size, @base2.size].max
    File.open(@report, 'w') do |f|
      f.puts sprintf("%#{w}s     total        common       unique", ' ')
      f.puts sprintf("%#{w}s %5d %6.3f %5d %6.3f %5d %6.3f", @base1, @list1.size, sum_times(@list1), @common_count, @common_time_1, @unique1.size, sum_times(@unique1))
      f.puts sprintf("%#{w}s %5d %6.3f %5d %6.3f %5d %6.3f", @base2, @list2.size, sum_times(@list2), @common_count, @common_time_2, @unique2.size, sum_times(@unique2))
    end
    puts sprintf("%#{w}s     total        common       unique", ' ')
    puts sprintf("%#{w}s %5d %6.3f %5d %6.3f %5d %6.3f", @base1, @list1.size, sum_times(@list1), @common_count, @common_time_1, @unique1.size, sum_times(@unique1))
    puts sprintf("%#{w}s %5d %6.3f %5d %6.3f %5d %6.3f", @base2, @list2.size, sum_times(@list2), @common_count, @common_time_2, @unique2.size, sum_times(@unique2))
  end
end

#
# ---------------------------------------------------------
# MAIN ROUTINE
# ---------------------------------------------------------
#
begin
  c = Comparer.new(ARGV)
  c.parse_files
  c.compare_files
  c.dump_remainders
  c.report
rescue UserInputError
  puts "ERROR: #{$!}"
end
