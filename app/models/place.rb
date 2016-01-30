class Place
  attr_accessor :id, :formatted_address, :location, :address_components
  
  def initialize params
    @id, @formatted_address = params[:_id].to_s, params[:formatted_address]
    @address_components = params[:address_components].map {|ac| AddressComponent.new(ac)}
    @location = Point.new(params[:geometry][:geolocation])
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

  def destroy
    self.class.collection.find(_id: BSON::ObjectId.from_string(@id)).delete_one
  end
end