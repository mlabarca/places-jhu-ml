class Place
  include ActiveModel::Model
  attr_accessor :id, :formatted_address, :location, :address_components
  
  def initialize params
    @id, @formatted_address = params[:_id].to_s, params[:formatted_address]
    @address_components = params[:address_components].map {|ac| AddressComponent.new(ac)} if params[:address_components]
    @location = Point.new(params[:geometry][:geolocation])
  end
  
  def persisted?
    !@id.nil?
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client['places']
  end

  def self.load_all data
    data_array = JSON.parse File.read(data)
    collection.insert_many(data_array)
  end

  def self.find_by_short_name short_name
    collection.find('address_components.short_name' => short_name)
  end

  def self.to_places mongo_places
    mongo_places.map{|m_place| Place.new(m_place)}
  end

  def self.find id
    result = collection.find(_id: BSON::ObjectId.from_string(id)).first
    return result.nil? ? nil : Place.new(result)
  end

  def self.all(offset = 0, limit = nil)
    result = collection.find().skip(offset)
    result = result.limit(limit) if limit.presence

    return to_places(result)
  end

  def photos skip = 0, limit = nil
    photos = Photo.find_photos_for_place(id).skip(skip)
    photos = photos.limit(limit) if limit.presence
    photos.map{|p| Photo.new(p)}
  end

  def destroy
    self.class.collection.find(_id: BSON::ObjectId.from_string(@id)).delete_one
  end

  # Gets a list of addresses with locations, returns mongo view
  def self.get_address_components(sort = {}, offset = 0, limit = nil)
    fields = %w[_id address_components formatted_address geometry.geolocation]
    projection = fields.each_with_object({}){|key, p| p[key] = 1}
    
    aggregate_query = [
      {"$unwind" => "$address_components"}, 
      {"$project" => projection},
    ]
    aggregate_query << {"$sort" => sort} if sort.presence 
    aggregate_query << {"$skip" => offset} if offset.presence 
    aggregate_query << {"$limit" => limit} if limit.presence 
    collection.find().aggregate(aggregate_query)
  end
  
  # Fetches a list of available countries in places database, returns array
  def self.get_country_names
    fields = %w[address_components.long_name address_components.types]
    projection = fields.each_with_object({}){|key, p| p[key] = 1}
    
    aggregate_query = [
      {"$project" => projection},
      {"$unwind"  => "$address_components"},
      {"$unwind"  => "$address_components.types"},
      {"$match"   => {"address_components.types" => "country"}},
      {"$group"   => {"_id" => "$address_components.long_name" }}
    ]
    country_docs = collection.find().aggregate(aggregate_query).to_a
    country_docs.map{|country_doc| country_doc[:_id]}
  end

  # Finds ids of all places with given country code, returns array
  def self.find_ids_by_country_code country_code
    aggregate_query = [
      {"$match"   => 
        {"$and" => [
          "address_components.types"      => {"$in" => ["country"]},
          "address_components.short_name" => {"$eq" => country_code}
        ]}
      },
      {"$project" => {"_id" => 1}},
    ]
    docs = collection.find().aggregate(aggregate_query).to_a
    docs.map{|doc| doc[:_id].to_s}
  end


  # Creates a 2dsphere index for location property
  def self.create_indexes
    collection.indexes.create_one( { "geometry.geolocation" => "2dsphere" } )
  end

  # Removes 2dsphere indexes
  def self.remove_indexes
    collection.indexes.drop_one("geometry.geolocation_2dsphere")
  end

  def self.near location, max_meters = nil
    geo_query = {
      "geometry.geolocation" => {
        "$near" => {"$geometry" => location.to_hash} 
      }
    }
    if max_meters.presence
      geo_query["geometry.geolocation"]["$near"]["$maxDistance"] = max_meters
    end
    collection.find(geo_query)
  end


  def near max_meters = nil
    near_places = Place.near(self.location, max_meters)
    Place.to_places(near_places)
  end

end