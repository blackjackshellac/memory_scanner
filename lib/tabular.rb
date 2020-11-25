#!/usr/bin/env ruby

# based on https://stackoverflow.com/questions/28684598/print-an-array-into-a-table-in-ruby
# col_labels = { date: "Date", from: "From", subject: "Subject" }
# arr = [{date: "2014-12-01", from: "Ferdous", subject: "Homework this week"},
#        {date: "2014-12-01", from: "Dajana", subject: "Keep on coding! :)"},
#        {date: "2014-12-02", from: "Ariane", subject: "Re: Homework this week"}]
#
#  @columns = col_labels.each_with_object({}) { |(col,label),h|
#    h[col] = { label: label,
#               width: [arr.map { |g| g[col].size }.max, label.size].max } }
#    # => {:date=>    {:label=>"Date",    :width=>10},
#    #     :from=>    {:label=>"From",    :width=>7},
#    #     :subject=> {:label=>"Subject", :width=>22}}
#
#  def write_header
#    puts "| #{ @columns.map { |_,g| g[:label].ljust(g[:width]) }.join(' | ') } |"
#  end
#
#  def write_divider
#    puts "+-#{ @columns.map { |_,g| "-"*g[:width] }.join("-+-") }-+"
#  end
#
#  def write_line(h)
#    str = h.keys.map { |k| h[k].ljust(@columns[k][:width]) }.join(" | ")
#    puts "| #{str} |"
#  end
#  write_divider
# write_header
# write_divider
# arr.each { |h| write_line(h) }
# write_divider
#
# +------------+---------+------------------------+
# | Date       | From    | Subject                |
# +------------+---------+------------------------+
# | 2014-12-01 | Ferdous | Homework this week     |
# | 2014-12-01 | Dajana  | Keep on coding! :)     |
# | 2014-12-02 | Ariane  | Re: Homework this week |
# +------------+---------+------------------------+

class Tabular
	MIN_WIDTH = 5

	def initialize(col_labels)
		# initialize column labels hash
		@col_labels = col_labels
		@data_keys = @col_labels.keys
		@arr = []
		@columns = {}
	end

	def validate_row(data)
		@data_keys.each { |key|
			next if data.key?(key)
			raise "row data missing value for column label %s" % @col_labels[key]
		}
	end

	DEF_ADD_ROW_OPTS={}
	##
	# Use label == :header to set column labels
	# :header\t[:a, :b, :c].join("\t")
	def addrow(data, opts=DEF_ADD_ROW_OPTS)
		#opts=DEF_ADD_ROW_OPTS.merge(opts)
		validate_row(data)
		@arr << data
	end

	def columnize
		@columns = @col_labels.each_with_object({}) { |(key,label),h|
			h[key] = {
				label: label,
				width: [
					@arr.map { |g|
						g[key].size
					}.max, label.size
				].max
			}
			#h[key][:width] += 1
		}
	end

	 def write_header
	   headers=@columns.map { |_,g|
			g[:label].to_s.center(g[:width])
		}
		puts "| "+headers.join(' | ')+" |"
	 end

	 def write_divider
	   puts "+-#{ @columns.map { |_,g| "-"*g[:width] }.join("-+-") }-+"
	 end

	 def write_line(h)
	   lines = h.keys.map { |k|
			h[k].to_s.ljust(@columns[k][:width])
		}
		str = lines.join(" | ")
	   puts "| #{str} |"
	 end

	def print
		columnize if @columns.empty?

		write_divider
		write_header
		write_divider
		@arr.each { |data| write_line(data) }
		write_divider
	end
end

@headers = {
	rowlabel: "",
	total: "Total",
	used:	"Used",
	pused: "%Used",
	free: "Free",
	pfree: "%Free"
}

table=Tabular.new(@headers)
table.addrow( {
	rowlabel: "Memory",
	total: 10,
	used: 5,
	pused: "50%",
	free: 5,
	pfree: "50%"
	})
table.addrow({
	rowlabel: "Swap",
	total: 2,
	used: 1,
	pused: "50%",
	free: 1,
	pfree: "50%"
	})

table.print
