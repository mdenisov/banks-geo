// Generated by CoffeeScript 1.6.3
/*
@author: Maxim Denisov (denisovmax1988@yandex.ru)
@date: 19/10/2013
@version: 0.1.1
@copyright: Banki.ru (www.banki.ru)
*/

var BanksGeo,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

BanksGeo = (function() {
  function BanksGeo(container, options) {
    this.init = __bind(this.init, this);
    this._messages = {
      empty_map: 'Error: Empty map',
      empty_options: 'Error: Empty map options',
      empty_center: 'Error: Empty center',
      empty_zoom: 'Error: Empty zoom',
      bad_data: 'Error: Bad data object',
      bad_response: 'Error: Bad data object'
    };
    this._data = [];
    this._map = null;
    this._container = null;
    this._$container = null;
    this._region = null;
    this._serviceUrl = '/api/';
    this._ajaxCount = 0;
    this._center = [];
    this._zoom = 10;
    this._regionIds = ['4', '211'];
    this._useMapControl = true;
    if ((container == null) && typeof container !== "string") {
      return this.log(this._messages.empty_map);
    }
    if ((options == null) && typeof container !== "object") {
      return this.log(this._messages.empty_options);
    }
    if ((options.region != null) && parseInt(options.region, 10) > 0) {
      this._region = options.region;
    } else {
      if (options.center == null) {
        return this.log(this._messages.empty_center);
      }
      if (options.zoom == null) {
        return this.log(this._messages.empty_zoom);
      }
    }
    if (options.mapControls != null) {
      this._useMapControl = options.mapControls === true ? true : false;
    }
    this._container = '#' + container;
    this._$container = $(this._container);
    this._center = options.center;
    this._zoom = options.zoom;
    this._$container.addClass('banks-geo').append('<div class="banks-geo__loader"/>');
    this._loader = this._$container.children('.banks-geo__loader');
    if (options.data != null) {
      if (typeof options.data === 'object') {
        this._data = options.data;
      }
    }
    this.init();
  }

  BanksGeo.prototype.init = function() {
    if (this._region != null) {
      return this.getCenterByRegion();
    } else {
      return this.initMap();
    }
  };

  BanksGeo.prototype._getAjaxCount = function() {
    this._ajaxCount++;
    return this._ajaxCount.toString();
  };

  BanksGeo.prototype._sendAjax = function(options, callback) {
    var _this = this;
    options = options || {};
    return $.ajax(this._serviceUrl, {
      cache: false,
      type: 'POST',
      dataType: 'json',
      data: JSON.stringify({
        "jsonrpc": "2.0",
        "method": options.method,
        "params": options.params,
        "id": this._getAjaxCount()
      }),
      error: function(jqXHR, textStatus, errorThrown) {
        return _this.log("AJAX Error: " + textStatus);
      },
      success: function(data, textStatus, jqXHR) {
        return callback != null ? callback.call(_this, data.result) : void 0;
      }
    });
  };

  BanksGeo.prototype._isUseClusters = function() {
    var _ref;
    if ((this._region != null) && (_ref = this._region, __indexOf.call(this._regionIds, _ref) >= 0)) {
      return true;
    } else {
      return false;
    }
  };

  BanksGeo.prototype.getDataByRegion = function() {
    var options;
    options = {
      method: 'region/get',
      params: {
        id: this._region
      }
    };
    return this._sendAjax(options, this.processMapOptions);
  };

  BanksGeo.prototype.processMapOptions = function(result) {
    var data;
    if (result.data != null) {
      data = result.data;
      this._center = [parseFloat(data.latitude, 10), parseFloat(data.longitude, 10)];
      this._zoom = parseInt(data.zoom, 10);
      return this.initMap();
    } else {
      return this.log(this._messages.bad_response);
    }
  };

  BanksGeo.prototype.initMap = function() {
    var _this = this;
    return ymaps.ready(function() {
      _this._map = new ymaps.Map(_this._$container[0], {
        _center: _this._center,
        _zoom: _this._zoom
      });
      if (_this._useMapControl === true) {
        _this._map.controls.add('zoomControl', {
          left: 5,
          top: 5
        });
      }
      _this.buildGeoCollection();
      if ((_this._data != null) && _this._data.length > 0) {
        return _this.processData({
          data: _this._data
        });
      } else {
        return _this.getPointsData();
      }
    });
  };

  BanksGeo.prototype.setData = function(data) {
    if ((data == null) || typeof data !== "object" || data.length === 0) {
      return this.log(this._messages.bad_data);
    } else {
      return this._data = data;
    }
  };

  BanksGeo.prototype.getPointsData = function() {
    var coords, options;
    coords = this.map.getBounds();
    options = {
      method: 'bankGeo/getObjectsByFilter',
      params: {
        fields: ['bank_id', 'latitude', 'longitude', 'type', 'is_main', 'icon_url'],
        region_id: [this._region],
        type: ["office", "branch", "atm"],
        longitude_nw: coords[0][1],
        latitude_nw: coords[1][0],
        longitude_se: coords[1][1],
        latitude_se: coords[0][0],
        zoom: this._zoom
      }
    };
    if (this._isUseClusters()) {
      options.method = 'bankGeo/getClusters';
      options.params.region_id = this._region;
      delete options.params.fields;
    }
    return this._sendAjax(options, this.processData);
  };

  BanksGeo.prototype.buildGeoCollection = function() {
    if (this._isUseClusters() === true) {
      this._collection = new ymaps.GeoObjectCollection();
    } else {
      this._collection = new ymaps.Clusterer({
        gridSize: 128,
        preset: "twirl#blackClusterIcons",
        margin: 25,
        minClusterSize: 2,
        clusterDisableClickZoom: false,
        balloonShadow: false
      });
    }
    return this.addToMap(this._collection);
  };

  BanksGeo.prototype.processData = function(result) {
    if ((result.data != null) && result.data.length > 0) {
      this._data = result.data;
      if (this._data.length > 500) {
        this.processBigData();
      } else {
        this.appendItemsToCollection(this._data);
      }
    }
    return this.setLoader(false);
  };

  BanksGeo.prototype.processBigData = function() {
    var tmp,
      _this = this;
    tmp = this._data.concat();
    return setTimeout(function() {
      var points;
      points = tmp.splice(0, 1000);
      _this.appendItemsToCollection(points);
      if (tmp.length > 0) {
        return setTimeout(arguments.callee, 25);
      }
    }, 25);
  };

  BanksGeo.prototype.buildGeoObject = function(object) {
    var icon, size;
    if ((object.points_count != null) && object.points_count > 1) {
      size = 's';
      icon = ymaps.templateLayoutFactory.createClass('<div class="banks-geo__cluster banks-geo__cluster--$[properties.size]" data-type="$[properties.points]">$[properties.points]</div>', {
        build: function() {
          return icon.superclass.build.call(this);
        },
        clear: function() {
          return icon.superclass.clear.call(this);
        }
      });
      if (object.points_count >= 1000) {
        size = 'b';
      } else if (object.points_count >= 10) {
        size = 'm';
      }
      return new ymaps.Placemark([object.latitude, object.longitude], {
        size: size,
        points: object.points_count,
        iconContent: object.points_count
      }, {
        iconLayout: icon
      });
    } else {
      icon = ymaps.templateLayoutFactory.createClass('<div class="banks-geo__point $[properties.type] $[properties.main]" data-type="$[properties.type]">$[properties.icon_url]</div>', {
        build: function() {
          return icon.superclass.build.call(this);
        },
        clear: function() {
          return icon.superclass.clear.call(this);
        }
      });
      return new ymaps.Placemark([object.latitude, object.longitude], {
        id: object['id'],
        type: 'banks-geo__point--' + object.type,
        main: object.is_main === true ? 'banks-geo__point--main' : '',
        icon_url: object.icon_url != null ? '<img src="' + object.icon_url + '">' : '',
        hintContent: object.name,
        balloonContent: object.address
      }, {
        hasHint: true,
        iconLayout: icon,
        balloonCloseButton: true,
        balloonShadow: false
      });
    }
  };

  BanksGeo.prototype.appendItemsToCollection = function(objects) {
    var i, iterations, _results;
    iterations = objects.length % 8;
    i = objects.length - 1;
    while (iterations > 0) {
      this.appendToCollection(this.buildGeoObject(objects[i--]));
      iterations--;
    }
    iterations = Math.floor(objects.length / 8);
    _results = [];
    while (iterations > 0) {
      this.appendToCollection(this.buildGeoObject(objects[i--]));
      this.appendToCollection(this.buildGeoObject(objects[i--]));
      this.appendToCollection(this.buildGeoObject(objects[i--]));
      this.appendToCollection(this.buildGeoObject(objects[i--]));
      this.appendToCollection(this.buildGeoObject(objects[i--]));
      this.appendToCollection(this.buildGeoObject(objects[i--]));
      this.appendToCollection(this.buildGeoObject(objects[i--]));
      this.appendToCollection(this.buildGeoObject(objects[i--]));
      _results.push(iterations--);
    }
    return _results;
  };

  BanksGeo.prototype.appendToCollection = function(object) {
    return this._collection.add(object);
  };

  BanksGeo.prototype.setLoader = function(state) {
    if ((state != null) && state === true) {
      return this._loader.show();
    } else {
      return this._loader.hide();
    }
  };

  BanksGeo.prototype.addToMap = function(object) {
    return this._map.geoObjects.add(object);
  };

  BanksGeo.prototype.setCenter = function(center, zoom) {
    return this._map.setCenter(center, zoom);
  };

  BanksGeo.prototype.setZoom = function(zoom) {
    return this._map.setCenter(zoom);
  };

  BanksGeo.prototype.log = function(message) {
    return console.log(message);
  };

  return BanksGeo;

})();
