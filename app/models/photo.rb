class Photo
  attr_accessor :id, :location
  attr_writer :contents

  def self.mongo_client
    Mongoid::Clients.default
  end

  def initialize params = {}
    @id = params[:_id].to_s if params[:_id]
    @location = Point.new(params[:metadata][:location]) if params[:metadata]
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
  
  # Save jpeg in contents to gridfs in mongo and update instance variables
  def save
    if !persisted? && @contents
      gps = EXIFR::JPEG.new(@contents).gps
      location = Point.new(:lng => gps.longitude, :lat => gps.latitude)
      
      @contents.rewind # Reposition read location to beggining of file
      
      params = {content_type: "image/jpeg", metadata: {location: location.to_hash}}
      grid_file = Mongo::Grid::File.new(@contents.read, params) # Unsaved gridfs file

      # Store file to mongo db
      id = self.class.mongo_client.database.fs.insert_one(grid_file)

      @location = location
      @id = id.to_s
    end
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


end