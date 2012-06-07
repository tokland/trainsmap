_(window).extend_from(_, 
  ["first", "last", "bind", "map", "mash", "zip", "mapDetect", "flatten1", 
   "pairwise", "flatMap", "compact"])

position = (lat, lon) ->
  new google.maps.LatLng(lat, lon)

class Time
  constructor: (@hour, @minute = 0) ->
  @fromString: (string) ->
    [hour, minute] = (parseInt(x) for x in string.split(/[.:]/)) 
    new Time(hour, minute or 0)
  toString: -> "Time[#{@hour}:#{@minute}]"
  valueOf: -> @hour * 60 + @minute
  add: (ms) -> new Time(Math.floor((this + ms) / 60), (this + ms) % 60) 

class Station
  constructor: (@name, @lat, @lon) ->
  position: -> position(@lat, @lon)

class Line
  constructor: (@name, @direction, @stations, @routes) ->
  
class LineRoute
  constructor: (@stations, @times) ->
    ts = compact(@times)
    throw("Empty LineRoute") unless ts.length > 1
    @departure = first(ts) 
    @arrival = last(ts)

  getPositionForTime: (time) ->
    return null unless @departure <= time < @arrival
    mapDetect(pairwise(@times), ([t1, t2], idx) =>
      if t1 and t2 and t1 <= time < t2
        st1 = @stations[idx]
        st2 = @stations[idx+1]
        f = (time - t1) / (t2 - t1)
        position(st1.lat + f*(st2.lat - st1.lat), st1.lon + f*(st2.lon - st1.lon)) 
    )
          
class TrainsMap
  COLORS:
    "R1": "#79bde8"
    "R2": "#00a650"
    "R3": "#ef3e33"
    "R4": "#f9a13a"
    "R7": "#b77cb6"
    "R8": "#8b0066"
    
  constructor: (@options = {}) ->
    _(@options).defaults
      container: "trains_map"
      timetables_url: "/timetables.json"
    @map = new google.maps.Map $(@options.container).get(0),
      zoom: 9
      center: position(41.5, 2.3)
      mapTypeId: google.maps.MapTypeId.ROADMAP
    $.ajax(@options.timetables_url).
      done(bind(@processJSON, this))

  # draw stations from a JsonStructure.
  #
  # [{
  #   name: String
  #   stations: [{name: String, lat: Float, lon: Float}]
  #   times: {go: [[String]], back: [[String]]}
  # }]
  processJSON: (json) ->
    # draw from app objects, not from json
    for line in json
      for st in line.stations
        marker = new google.maps.Marker
          position: position(st.lat, st.lon)
          icon: "/station.gif"
          clickable: true
          title: st.name
          cursor: st.name
        #marker.setMap(@map)

      path = new google.maps.Polyline
        path: (position(st.lat, st.lon) for st in line.stations)
        strokeColor: @COLORS[line.name] or throw "No color defined for line #{line.name}"
        strokeOpacity: 1.0
        strokeWeight: 6
      path.setMap(@map)

    @lines = flatMap json, (line) ->
      newLineRoutes = (stations, direction) ->
        for string_times in line.times[direction]
          times = ((if t then Time.fromString(t) else null) for t in string_times)
          new LineRoute(stations, times) 

      stations = (new Station(o.name, o.lat, o.lon) for o in line.stations) 
      stations_rev = stations.slice().reverse()
      [new Line(line.name, "go", stations, newLineRoutes(stations, "go")),
       new Line(line.name, "back", stations_rev, newLineRoutes(stations_rev, "back"))]
       
    @markers = {}
    ms = 0
    setInterval(=>
      t = (new Time(4, 59)).add(ms)
      $("#info").html(t.toString()) 
      @drawTrains(t)
      ms += 1  
    , 200)
    
  drawTrains: (time) ->
    markers = for line in @lines
      for route in line.routes
        if (pos = route.getPositionForTime(time))
          ident = "#{line.name}: #{route.departure.toString()} -> #{route.arrival.toString()}"
          marker = if (marker = @markers[ident])
            marker.setPosition(pos)
            marker.setMap(@map)
            marker
          else
            marker = new google.maps.Marker
              position: pos
              icon: "/train.gif"
              clickable: true
              title: ident
            marker.setMap(@map)
            marker
          [ident, marker]

    # remove (from hash and map) non-touched markers
    @markers = mash(compact(flatten1(markers)))          
          
$ ->
  window.trains_map = new TrainsMap
    container: "#map_canvas"
    timetables_url: "/timetables.json"
