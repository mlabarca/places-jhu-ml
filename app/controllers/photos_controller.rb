class PhotosController < ApplicationController
  def show
    @photo = Photo.find(params[:id])
    if @photo.presence
      send_data @photo.contents, { type: 'image/jpeg', disposition: 'inline'}
    end
  end
end
