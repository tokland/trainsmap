# encoding: utf-8
require 'pdf-reader'
require 'json'
require 'active_support/core_ext/hash'
require 'enumerable/lazy'
require 'pp'

require './extensions'

class TimeTablesParser
  INFO = {
    "R1" => {
      :file => "pdf/R1_40x100_28 agosto.pdf",
      :page_go => 1,
      :page_back => 2,
      :stations => [
        "Molins de Rei", "Sant Feliu de Llobregat", "Sant Joan Despí", "Cornellà",
        "L'Hospitalet de Llobregat", "Barcelona-Sants", "Barcelona-Plaça de Catalunya",
        "Barcelona-Arc de Triomf", "Barcelona-El Clot-Aragó", "Sant Adrià del Besòs",
        "Badalona", "Montgat", "Montgat Nord", "El Masnou", "Ocata", "Premià de Mar", 
        "Vilassar de Mar", "Cabrera de Mar-Vilassar de Mar", "Mataró", 
        "Sant Andreu de Llavaneres", "Caldes d'Estrac", "Arenys de Mar",
        "Canet de Mar", "Sant Pol de Mar", "Calella", "Pineda de Mar", 
        "Santa Susanna", "Malgrat de Mar", "Blanes", "Tordera", "Maçanet-Massanes",
      ],
    },

    "R2" => {
      :file => "pdf/R2_R2S_R2N_StVicençC-Maçanet_111211.pdf",
      :page_go => 1,
      :page_back => 2,
      :stations => [
        "Maçanet-Massanes", "Hostalric", "Riells i Viabrea-Breda", "Gualba",
        "Sant Celoni", "Palautordera", "Llinars del Vallès", "Cardedeu", 
        "Les Franqueses-Granollers Nord", "Granollers Centre", "Montmeló",
        "Mollet-Sant Fost", "La Llagosta", "Montcada i Reixac", 
        "Barcelona-Sant Andreu Comtal", "Barcelona-El Clot-Aragó",
        "Barcelona-Estació de França", "Barcelona-Passeig de Gràcia",
        "Barcelona-Sants", "Bellvitge", "El Prat de Llobregat", "Aeroport",
        "Viladecans", "Gavà", "Castelldefels", "Platja de Castelldefels",
        "Garraf", "Sitges", "Vilanova i la Geltrú", "Cubelles", "Cunit",
        "Segur de Calafell", "Calafell", "Sant Vicenç de Calders", 
      ],
    },
  }

  def parse_all
    stations_info = JSON::load(open("stations.json")).mash do |st|
      [st["name"], st.except("name").symbolize_keys]
    end
    
    INFO.lazy.map do |line, info|
      reader = PDF::Reader.new(info[:file])
      
      times = [:go, :back].lazy.mash do |direction|
        $stderr.puts "#{info[:file]}: #{line} - #{direction}"
        npage = info[:"page_#{direction}"] - 1
        page = reader.pages[npage]
        lines = page.text.lines.drop_while do |s|
          !s.split.first.match(/\d+\.\d+/)
        end.take_while do |s|
          s.split.first.match(/\d+\.\d+/)
        end
        all_times = lines.map do |line|
          empty_fields = line.match(/^([^.]*)/)[1].size - 2
          times = line.scan(/\d{1,2}\.\d{2}/)
          $stderr.puts "[#{empty_fields}] #{times.join(' ')}"
          [nil]*empty_fields  + times
        end
        
        [direction.to_s, all_times]
      end

      stations = info[:stations].map do |station_name|
        st = stations_info[station_name] or die("No station found: #{station_name}")
        {name: station_name, lat: st[:lat], lon: st[:lon]}
      end
      {name: line, stations: stations, times: times}
    end
  end
end 

if __FILE__ == $0
  parser = TimeTablesParser.new
  json = JSON.pretty_generate(parser.parse_all.to_a)
  File.write("timetables.json", json)
end
