require 'controller'
require 'assets/models/device'

module App
  class Base < Controller
    namespace '/api/ipxe' do
      get '/boot' do
        content_type 'text/plain'

        if params[:id]
          device = Device.find(params[:id])
        elsif params[:mac] and not params[:mac].empty?
          device = Device.urlsearch("mac/#{params[:mac]}").to_a.first
        elsif params[:uuid] and not params[:uuid].empty?
          device = Device.urlsearch("uuid/#{params[:uuid]}").to_a.first
        end

        liquid "ipxe/boot".to_sym, :locals => {
          :device => (device.to_h rescue nil),
          :config => Config.get('provisioning.boot')
        }
      end
    end
  end
end