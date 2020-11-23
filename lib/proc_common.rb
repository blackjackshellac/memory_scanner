#!/usr/bin/env ruby
#
#


module Procfs

	class Common
		NAME_VALUE_REGEX=/(?<name>[^:]+)[:]\s+(?<value>.*?)(?<kbytes>\skB)?$/

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
