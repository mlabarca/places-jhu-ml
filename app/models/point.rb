class Point
  attr_accessor :latitude, :longitude
  
  # GEOJson Format
  def to_hash
    {type: "Point", coordinates: [@longitude, @latitude]}
  end
  
  # Accepts geo json format or lat lng format
  def initialize params
    is_geo_json = params[:type] == "Point"
    if is_geo_json
      @longitude, @latitude = params[:coordinates]
    else
      @longitude, @latitude = params[:lng], params[:lat]
    end
  end
end