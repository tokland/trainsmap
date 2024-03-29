// Generated by CoffeeScript 1.3.1
(function() {
  var Line, LineRoute, Station, Time, TrainsMap, position;

  _(window).extend_from(_, ["first", "last", "bind", "map", "mash", "zip", "mapDetect", "flatten1", "pairwise", "flatMap", "compact"]);

  position = function(lat, lon) {
    return new google.maps.LatLng(lat, lon);
  };

  Time = (function() {

    Time.name = 'Time';

    function Time(hour, minute) {
      this.hour = hour;
      this.minute = minute != null ? minute : 0;
    }

    Time.fromString = function(string) {
      var hour, minute, x, _ref;
      _ref = (function() {
        var _i, _len, _ref, _results;
        _ref = string.split(/[.:]/);
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          x = _ref[_i];
          _results.push(parseInt(x));
        }
        return _results;
      })(), hour = _ref[0], minute = _ref[1];
      return new Time(hour, minute || 0);
    };

    Time.prototype.toString = function() {
      return "Time[" + this.hour + ":" + this.minute + "]";
    };

    Time.prototype.valueOf = function() {
      return this.hour * 60 + this.minute;
    };

    Time.prototype.add = function(ms) {
      return new Time(Math.floor((this + ms) / 60), (this + ms) % 60);
    };

    return Time;

  })();

  Station = (function() {

    Station.name = 'Station';

    function Station(name, lat, lon) {
      this.name = name;
      this.lat = lat;
      this.lon = lon;
    }

    Station.prototype.position = function() {
      return position(this.lat, this.lon);
    };

    return Station;

  })();

  Line = (function() {

    Line.name = 'Line';

    function Line(name, direction, stations, routes) {
      this.name = name;
      this.direction = direction;
      this.stations = stations;
      this.routes = routes;
    }

    return Line;

  })();

  LineRoute = (function() {

    LineRoute.name = 'LineRoute';

    function LineRoute(stations, times) {
      var ts;
      this.stations = stations;
      this.times = times;
      ts = compact(this.times);
      if (!(ts.length > 1)) {
        throw "Empty LineRoute";
      }
      this.departure = first(ts);
      this.arrival = last(ts);
    }

    LineRoute.prototype.getPositionForTime = function(time) {
      var _this = this;
      if (!((this.departure <= time && time < this.arrival))) {
        return null;
      }
      return mapDetect(pairwise(this.times), function(_arg, idx) {
        var f, st1, st2, t1, t2;
        t1 = _arg[0], t2 = _arg[1];
        if (t1 && t2 && (t1 <= time && time < t2)) {
          st1 = _this.stations[idx];
          st2 = _this.stations[idx + 1];
          f = (time - t1) / (t2 - t1);
          return position(st1.lat + f * (st2.lat - st1.lat), st1.lon + f * (st2.lon - st1.lon));
        }
      });
    };

    return LineRoute;

  })();

  TrainsMap = (function() {

    TrainsMap.name = 'TrainsMap';

    TrainsMap.prototype.COLORS = {
      "R1": "#79bde8",
      "R2": "#00a650",
      "R3": "#ef3e33",
      "R4": "#f9a13a",
      "R7": "#b77cb6",
      "R8": "#8b0066"
    };

    function TrainsMap(options) {
      this.options = options != null ? options : {};
      _(this.options).defaults({
        container: "trains_map",
        timetables_url: "/timetables.json"
      });
      this.map = new google.maps.Map($(this.options.container).get(0), {
        zoom: 9,
        center: position(41.5, 2.3),
        mapTypeId: google.maps.MapTypeId.ROADMAP
      });
      $.ajax(this.options.timetables_url).done(bind(this.processJSON, this));
    }

    TrainsMap.prototype.processJSON = function(json) {
      var line, marker, ms, path, st, _i, _j, _len, _len1, _ref,
        _this = this;
      for (_i = 0, _len = json.length; _i < _len; _i++) {
        line = json[_i];
        _ref = line.stations;
        for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
          st = _ref[_j];
          marker = new google.maps.Marker({
            position: position(st.lat, st.lon),
            icon: "/station.gif",
            clickable: true,
            title: st.name,
            cursor: st.name
          });
        }
        path = new google.maps.Polyline({
          path: (function() {
            var _k, _len2, _ref1, _results;
            _ref1 = line.stations;
            _results = [];
            for (_k = 0, _len2 = _ref1.length; _k < _len2; _k++) {
              st = _ref1[_k];
              _results.push(position(st.lat, st.lon));
            }
            return _results;
          })(),
          strokeColor: this.COLORS[line.name] || (function() {
            throw "No color defined for line " + line.name;
          })(),
          strokeOpacity: 1.0,
          strokeWeight: 6
        });
        path.setMap(this.map);
      }
      this.lines = flatMap(json, function(line) {
        var newLineRoutes, o, stations, stations_rev;
        newLineRoutes = function(stations, direction) {
          var string_times, t, times, _k, _len2, _ref1, _results;
          _ref1 = line.times[direction];
          _results = [];
          for (_k = 0, _len2 = _ref1.length; _k < _len2; _k++) {
            string_times = _ref1[_k];
            times = (function() {
              var _l, _len3, _results1;
              _results1 = [];
              for (_l = 0, _len3 = string_times.length; _l < _len3; _l++) {
                t = string_times[_l];
                _results1.push(t ? Time.fromString(t) : null);
              }
              return _results1;
            })();
            _results.push(new LineRoute(stations, times));
          }
          return _results;
        };
        stations = (function() {
          var _k, _len2, _ref1, _results;
          _ref1 = line.stations;
          _results = [];
          for (_k = 0, _len2 = _ref1.length; _k < _len2; _k++) {
            o = _ref1[_k];
            _results.push(new Station(o.name, o.lat, o.lon));
          }
          return _results;
        })();
        stations_rev = stations.slice().reverse();
        return [new Line(line.name, "go", stations, newLineRoutes(stations, "go")), new Line(line.name, "back", stations_rev, newLineRoutes(stations_rev, "back"))];
      });
      this.markers = {};
      ms = 0;
      return setInterval(function() {
        var t;
        t = (new Time(4, 59)).add(ms);
        $("#info").html(t.toString());
        _this.drawTrains(t);
        return ms += 1;
      }, 200);
    };

    TrainsMap.prototype.drawTrains = function(time) {
      var ident, line, marker, markers, pos, route;
      markers = (function() {
        var _i, _len, _ref, _results;
        _ref = this.lines;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          line = _ref[_i];
          _results.push((function() {
            var _j, _len1, _ref1, _results1;
            _ref1 = line.routes;
            _results1 = [];
            for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
              route = _ref1[_j];
              if ((pos = route.getPositionForTime(time))) {
                ident = "" + line.name + ": " + (route.departure.toString()) + " -> " + (route.arrival.toString());
                marker = (marker = this.markers[ident]) ? (marker.setPosition(pos), marker.setMap(this.map), marker) : (marker = new google.maps.Marker({
                  position: pos,
                  icon: "/train.gif",
                  clickable: true,
                  title: ident
                }), marker.setMap(this.map), marker);
                _results1.push([ident, marker]);
              } else {
                _results1.push(void 0);
              }
            }
            return _results1;
          }).call(this));
        }
        return _results;
      }).call(this);
      return this.markers = mash(compact(flatten1(markers)));
    };

    return TrainsMap;

  })();

  $(function() {
    return window.trains_map = new TrainsMap({
      container: "#map_canvas",
      timetables_url: "/timetables.json"
    });
  });

}).call(this);
