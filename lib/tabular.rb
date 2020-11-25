#!/usr/bin/env ruby
#
# based on https://stackoverflow.com/questions/28684598/print-an-array-into-a-table-in-ruby
#
# @headers = {
# 	rowlabel: "",
# 	total: "Total",
# 	used:	"Used",
# 	pused: "%Used",
# 	free: "Free",
# 	pfree: "%Free"
# }
#
# table=Tabular.new(@headers)
#
# table.addrow( {
# 	rowlabel: "Memory",
# 	total: 10,
# 	used: 5,
# 	pused: "50%",
# 	free: 5,
# 	pfree: "50%"
# 	})
#
# table.addrow({
# 	rowlabel: "Swap",
# 	total: 2,
# 	used: 1,
# 	pused: "50%",
# 	free: 1,
# 	pfree: "50%"
# 	})
#
# table.print

class Tabular
	MIN_WIDTH = 5

	attr_reader :rows
	def initialize(col_labels)
		# initialize column labels hash
		@col_labels = col_labels
		@data_keys = @col_labels.keys
		@rows = []
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
		@rows << data
	end

	def columnize
		@columns = @col_labels.each_with_object({}) { |(key,label),h|
			h[key] = {
				label: label,
				width: [
					@rows.map { |row|
						row[key].size
					}.max, label.size
				].max
			}
			#h[key][:width] += 1
		}
	end

	def header_to_s
		 headers=@columns.map { |_,g|
			g[:label].to_s.center(g[:width])
		}
		"| "+headers.join(' | ')+" |"
	end

	def divider_to_s
		 "+-#{ @columns.map { |_,g| "-"*g[:width] }.join("-+-") }-+"
	end

	def row_to_s(row)
		 lines = row.keys.map { |key|
			row[key].to_s.ljust(@columns[key][:width])
		}
		line = lines.join(" | ")
		"| #{line} |"
	end

	def to_s
		columnize if @columns.empty?

		s=""
		rowlines { |line|
			s += line + "\n"
		}
	end

	def rowlines
		yield (divider_to_s)
		yield (header_to_s)
		yield (divider_to_s)
		@rows.each { |row|
			yield (row_to_s(row))
		}
		yield (divider_to_s)
	end

	def print
		puts to_s
	end

	def self.test
		headers = {
			rowlabel: "",
			total: "Total",
			used:	"Used",
			pused: "%Used",
			free: "Free",
			pfree: "%Free"
		}

		table=Tabular.new(headers)

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
	end
end

Tabular.test
