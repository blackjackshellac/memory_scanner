#!/usr/bin/env ruby
#
#

module Procfs
	class Common
		NAME_VALUE_REGEX=/(?<name>[^:]+)[:]\s+(?<value>.*?)(?<kbytes>\skB)?$/
		PREFIX = %W(TiB GiB MiB KiB B).freeze

		def self.as_size(s, opts={:precision=>1} )
			s = s.to_f
			i = PREFIX.length - 1
			while s > 512 && i > 0
				i -= 1
				s /= 1024
			end
			((s > 9 || s.modulo(1) < 0.1 ? '%d' : "%.1f") % s) + ' ' + PREFIX[i]
		end

		def self.pid_dirs
			Dir.glob("/proc/[0-9]*").each { |pid_dir|
				yield(pid_dir)
			}
		end

		def self.symbolize(name)
			name.downcase.to_sym
		end

		def self.parse_name_value(entry, fields={})
			entry.split(/\n/).each { |line|
				m=line.match(NAME_VALUE_REGEX)
				name=symbolize(m[:name])
				value=m[:value]
				value=value.to_i*1024 unless m[:kbytes].nil?
				fields[name] = value
			}
			fields
		end

	end
end
