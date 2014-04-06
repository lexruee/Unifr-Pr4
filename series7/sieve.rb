#
# author: 	Alexander Rüedlinger
# date:		2014
#
#
# Naive, simple, ugly and inefficient implementation the 
# sieve of eratosthenes.
#
def sieve(max)
	nums = (2..max).to_a.map {|x| [x,true] }
	primes = [2]
	found = true
	while found
		p = primes.last
		found = false
		nums[1..-1].each_with_index do |n,i|
			
			num,b = n
			nums[i+1] = [num,false] if num % p == 0 and b
		end
		
		nums.each do |n|
			num,b = n
			if num > p and b
				primes << num
				found = true
				break
			end
		end
		
	end
	primes
end

puts sieve(100)
