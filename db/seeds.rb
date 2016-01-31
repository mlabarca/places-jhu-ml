# Clear GridFS of all files
Photo.all.each(&:destroy)

# Clear the places collection of all documents
Place.all.each(&:destroy)

# Make sure the 2dsphere index has been created 
Place.create_indexes

# Populate the places collection using the db/places.json file 
file = File.open("./db/places.json")
Place.load_all file

# Populate GridFS with the images also located in the db/ folder
Photo.load_all

# Locate the nearest place within one (1) mile of each photo and associate
Photo.all.each do |photo|
  near_place_id = photo.find_nearest_place_id(1 * 1609.34)
  photo.place = near_place_id
  photo.save
end