class Terms
  attr_reader :designer_map, :term_map, :terms

  def initialize(designer_map)
    @designer_map = designer_map
    @term_map = designer_map.invert
    @terms = designer_map.to_a.flatten
    @designer_map.each {|k,v| hashtag = v.gsub(/\s+/, ""); term_map[hashtag] = k; @terms << hashtag}
    @terms.uniq!
  end

  def list
    @terms
  end

  def normalize(term)
    return term_map[term] if @term_map.has_key?(term)
    term
  end

end