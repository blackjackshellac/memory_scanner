
##
# extend Numeric class
class Numeric
	SUFFIX_IB = %W(TiB GiB MiB KiB B).freeze

	##
	# print out numeric value with SUFFIX_IB
	def to_bibyte
		s = self.to_f
		i = SUFFIX_IB.length - 1
		while s > 512 && i > 0
			i -= 1
			s /= 1024
		end
		((s > 9 || s.modulo(1) < 0.1 ? '%d' : "%.1f") % s) + ' ' + SUFFIX_IB[i]
	end

end

##
# extend NilClass
class NilClass
	##
	# handle nil values
	def to_bibyte
		""
	end
end
