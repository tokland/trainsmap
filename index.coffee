position = (lat, lng) ->
  new google.maps.LatLng(lat, lng)

initMap = (container) ->
  options =
    zoom: 9
    center: position(41.5, 2.3)
    mapTypeId: google.maps.MapTypeId.ROADMAP
  map = new google.maps.Map($(container).get(0), options)
  marker = new google.maps.Marker({
    position: position(41.5, 1.7)
    icon: "https://developers.google.com/images/favicon.ico"
    clickable: true
    title: "Title"
    cursor: "Cursor"
  })
  
  #marker.setMap(map)
  #marker.setPosition(position(42, 1.7))
  window.map = map
  window.marker = marker

$ ->
  initMap("#map_canvas")
  $.ajax("/timetables.json").done (json) ->
    window.json = json
    colors = ["#F00", "#0F0", "#00F"]
    for line, idx in json
      coordinates = (position(st.lat, st.lon) for st in line.stations)
      path = new google.maps.Polyline({
        path: coordinates
        strokeColor: colors[idx]
        strokeOpacity: 1.0
        strokeWeight: 4
      })
      path.setMap(map)
