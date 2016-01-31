class Photo
  attr_accessor :id, :location, :place
  attr_writer :contents

  def self.mongo_client
    Mongoid::Clients.default
  end

  def initialize params = {}
    @id = params[:_id].to_s if params[:_id]
    @location = Point.new(params[:metadata][:location]) if params[:metadata]
    @place = params[:metadata][:place] if params[:metadata]
  end

  def contents
    # Fetch file from gridfs and write to file instance chunk by chunk
    stored_file = self.class.mongo_client.database.fs.find_one(_id: BSON::ObjectId.from_string(self.id))
    
    if stored_file
      file = ""
      stored_file.chunks.reduce([]) { |x, chunk| file << chunk.data.data }
      file
    end
  end
  
  def persisted?
   !@id.nil?
  end
  
  def place
    @place.presence ? Place.find(@place) : nil
  end

  def place=(place_id)
    place_id = BSON::ObjectId.from_string(place_id) if place_id.class == String
    @place = place_id
  end

  # Save jpeg in contents to gridfs in mongo and update instance variables
  def save
    if !persisted? 
      if @contents
        gps = EXIFR::JPEG.new(@contents).gps
        @location = Point.new(:lng => gps.longitude, :lat => gps.latitude)
        
        @contents.rewind # Reposition read location to beggining of file
        
        grid_file = Mongo::Grid::File.new(@contents.read, get_description) # Unsaved gridfs file

        # Store file to mongo db
        id = self.class.mongo_client.database.fs.insert_one(grid_file)

        @id = id.to_s
      end
    else
      file = self.class.mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(@id))
      file.update_one(get_description)
    end
  end

  def get_description
    description = {content_type: "image/jpeg"}
    if @location || @place
      description[:metadata] = {}
      description[:metadata][:location] = @location.to_hash if @location
      description[:metadata][:place] = @place
    end
    description
  end

  def destroy
    self.class.mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(@id)).delete_one
  end

  def self.all skip = 0, limit = nil
    docs = mongo_client.database.fs.find().skip(skip)
    docs = docs.limit(limit) if limit.presence
    
    return docs.map{|doc| Photo.new(doc)}
  end

  def self.find id
    result = mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(id)).first
    return result.nil? ? nil : Photo.new(result)
  end
  
  def find_nearest_place_id max_meters
    near_places = Place.near(@location, max_meters)
    nearest_place = near_places.limit(1)
    nearest_place = nearest_place.projection(_id: 1)
    nearest_place.find.to_a.first[:_id]
  end

end