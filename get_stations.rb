#!/usr/bin/env ruby
require 'nokogiri'
require 'yaml'
require 'rest-client'
require 'retryable'
require 'enumerable/lazy'
require 'active_support/core_ext/hash'

require './extensions'

module Rodalies
  class LinesDownloader 
    LOCAL_URL = "http://www20.gencat.cat/portal/site/rodalies/menuitem.b638815e53e7323fcfd97c10b0c0e1a0/?vgnextoid=d771acc98deff210VgnVCM2000009b0c1e0aRCRD&vgnextchannel=d771acc98deff210VgnVCM2000009b0c1e0aRCRD&vgnextfmt=default&tipologia=Rodalies"
    REGIONAL_URL = "http://www20.gencat.cat/portal/site/rodalies/menuitem.b638815e53e7323fcfd97c10b0c0e1a0/?vgnextoid=3eaff54f5eeff210VgnVCM2000009b0c1e0aRCRD&vgnextchannel=3eaff54f5eeff210VgnVCM2000009b0c1e0aRCRD&vgnextfmt=default&tipologia=Regionals"

    def stations
      [LOCAL_URL, REGIONAL_URL].lazy.flat_map do |url|
        doc = Nokogiri::HTML(safe { RestClient.get(url) })
        stations = doc.css("#contentRodalies tbody > tr").lazy.flat_map do |row|
          form = row.at_css("form")
          base_params = form.css("input").mash { |node| [node["name"], node["value"]] }
          
          form.css("select > option").lazy.map do |option|
            station_id = option["value"].to_i
            station_name = option.text
            params = base_params.merge(:est => station_id)
            station_url = URI::join(url, form["action"]).to_s
            
            response = safe { RestClient.get(station_url, :params => params) }
            page_doc = Nokogiri::HTML(response)
            title = page_doc.at_css(".FW_sInfoCanal h3") or die("Cannot find line") 
            line = title.text.split[1..-1].join
            
            match = response.match(/addPlaceMark\(([\d.]+),\s*([\d.]+),/) or
              die("Cannot find placemark for station: #{station_name}")
            lat, lon = match.captures.map(&:to_f)
            $stderr.puts [line, station_id, station_name, lat, lon].inspect
            
            {line: line, gencat_id: station_id, name: station_name, lat: lat, lon: lon}.stringify_keys
          end
        end
      end
    end

    def safe(&block)
      retryable(:on => Errno::ETIMEDOUT, :tries => 10, :sleep => 30, &block)
    end
  end
end

if __FILE__ == $0
  downloader = Rodalies::LinesDownloader.new
  File.write("stations.yaml", YAML::dump(downloader.stations.to_a))
end
