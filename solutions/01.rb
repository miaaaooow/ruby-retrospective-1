class Array
    
    def to_hash
        Hash[*self.flatten]
    end


    def index_by
        res = {}
        if block_given? 
            self.each do |x|
                res[yield(x)] = x
            end
        end
        res
    end

    
    def subarray_count(subarray)
        count = 0
        len = self.length
        for i in 0...len
            if full_match?(subarray, i)
                count += 1
            end
        end
        count
    end


    def occurences_count
        res = Hash.new(0) 
        self.map { |elem| res[elem] += 1 }
        res
    end

    #as ugly as I could :/
    private 
    def full_match? (arr2, pos)
        m = self.length
        n = arr2.length
        if (n > m - pos)
            false
        else 
            for i in 0...n  
                if self[i + pos] != arr2[i] 
                    return false 
                end
            end
            true
        end
    end
           
end


