class Song

  attr_accessor :name, :artist, :genre, :subgenre, :tags

  def initialize(name, artist, genre, subgenre="", tags)
    @name = name
    @artist = artist
    @genre = genre
    @subgenre = subgenre
    @tags = tags
  end

  def initialize (string_line)
    @name, @artist, @genre, tags = string_line.split(".").map{ |attribute| attribute.strip }
    @tags = tags.split(',').map{ |word| word.strip }
    @genre, @subgenre = @genre.split(',').strip if @genre.include? (",")
    @tags << @genre.downcase
    @tags << @subgenre.downcase if @subgenre
  end	

  def update_tags (artist, *new_tags)
    if artist == self.artist
      new_tags.each do |tag|
        @tags << tag
      end
    end
  end

  def satisfies? (criteria)
    criteria.each do |attr, value|
      if [ :name, :artist, :genre, :subgenre, :tags ].include? attr
        self.match_simple? attr, value
      elsif attr == :filter
        self.match_filter? &value
      end      
    end
  end


  #private 
  def match_simple? (key, values)
    if key == :tags 
      values.all? { |value| self.tags.include? (value) }
    else
      self.send(key) == values
    end      
  end

  def match_filter? (&block)
    block_given? and self.send(&block)   
  end
end


class Collection
  attr_accessor :songs, :artists
  
  def initialize(songs_as_string, artist_tags)
    @songs = Collection.extract_songs( songs_as_string )
    @artists = Collection.extract_artists( artist_tags )
  end
  
  def find(criteria)
    @songs.select { |song| song.satisfies? criteria }
  end


  def Collection.extract_songs(songs_as_string)
    songs = []
    songs_as_string.split('\n').each do |song_line|
      songs << Song.new(song_line)
    end
    songs
  end

  def Collection.extract_artists(artists_tags)
        
  end
end

