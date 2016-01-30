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
end