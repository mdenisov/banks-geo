###
@author: Maxim Denisov (denisovmax1988@yandex.ru)
@date: 19/10/2013
@version: 0.1.3
@copyright: Banki.ru (www.banki.ru)
###

#BanksGeo = exports? and exports or @BanksGeo = {}

class BanksGeo
	#@method: constructor
	#Constructor
	constructor: (container, options) ->
		@_messages = {
			empty_map: 'Error: Empty map'
			empty_options: 'Error: Empty map options'
			empty_center: 'Error: Empty center'
			empty_zoom: 'Error: Empty zoom'
			bad_data: 'Error: Bad data object'
			bad_response: 'Error: Bad data object'
		}

		@_data = []
		@_map = null
		@_container = null
		@_$container = null
		@_collection = null

		@_region = null
		@_serviceUrl = '/api/'
		@_ajaxCount = 0
		@_center = []
		@_zoom = 10
		@_regionIds = ['4', '211']

		@_useMapControl = true

		if not container? and typeof container isnt "string"
			return @log @_messages.empty_map

		if not options? and typeof container isnt "object"
			return @log @_messages.empty_options

		if options.region? and parseInt(options.region, 10) > 0
			@_region = options.region
		else
			unless options.center?
				return @log @_messages.empty_center

			unless options.zoom?
				return @log @_messages.empty_zoom

		if options.mapControls?
			@_useMapControl = if options.mapControls is true then true else false

		@_container = container
		@_$container = $(@_container)

		if not @_$container? or @_$container.length is 0
			return @log @_messages.empty_map

		@_center = options.center
		@_zoom = options.zoom

		@_$container.addClass('banks-geo').append('<div class="banks-geo__loader"/>')

		@_loader = @_$container.children('.banks-geo__loader')

		if options.data?
			if typeof options.data is 'object'
				@_data = options.data

		@init()

	#@method: init
	#Initialize Yandex Map and preprocess data
	init: () =>
		if @_region?
			@getDataByRegion()
		else
			@initMap()

	#@method: _getAjaxCount
	#Set point data
	_getAjaxCount: () ->
		@_ajaxCount++
		@_ajaxCount.toString()

	#@method: _sendAjax
	#Do API request
	_sendAjax: (options, callback) ->
		options = options || {};

		$.ajax @_serviceUrl,
			cache: false,
			type: 'POST',
			dataType: 'json',
			data: JSON.stringify({
				"jsonrpc": "2.0",
				"method": options.method,
				"params": options.params,
				"id": @_getAjaxCount()
			})
			error: (jqXHR, textStatus, errorThrown) =>
				@log "AJAX Error: #{textStatus}"
			success: (data, textStatus, jqXHR) =>
				callback?.call @, data.result

	#@method: _isUseClusters
	#Return use or not clusters for this region
	_isUseClusters: () ->
		if @_region? and @_region in @_regionIds
			true
		else
			false

	#@method: getCenterByRegion
	#Get data about region
	getDataByRegion: () ->
		options = {
			method: 'region/get'
			params: {
				id: @_region
			}
		}

		@._sendAjax(options, @processMapOptions);

	#@method: processMapOptions
	#Set center and zoom and run Map initialize
	processMapOptions: (result) ->
		if result? and result.data?
			data = result.data
			@_center = [parseFloat(data.latitude, 10), parseFloat(data.longitude, 10)]
			@_zoom = parseInt(data.zoom, 10)

			@initMap()
		else
			@log @_messages.bad_response


	#@method: initMap
	#Initialize Yandex Map
	initMap: () ->
		ymaps.ready( () =>
			@_map = new ymaps.Map(@_$container[0], {
				center: @_center
				zoom: @_zoom
			})

			if @_useMapControl is true
				@_map.controls.add('zoomControl', { left: 5, top: 5 })

			@buildGeoCollection()

			if @_data? and @_data.length > 0
				@processData(data: @_data)
			else
				@getPointsData()
		)

	#@method: setData
	#Set point data
	setData: (data) ->
		if not data? or typeof data isnt "object" or data.length is 0
			@log @_messages.bad_data
		else
			@_data = data

	#@method: getPointsData
	#Get point data
	getPointsData: () ->
		coords = @_map.getBounds()
		options = {
			method: 'bankGeo/getObjectsByFilter',
			params: {
				fields: ['bank_id', 'latitude', 'longitude', 'type', 'is_main', 'icon_url']
				region_id: [@_region]
				type: ["office","branch","atm"]
				longitude_nw: coords[0][1]
				latitude_nw: coords[1][0]
				longitude_se: coords[1][1]
				latitude_se: coords[0][0]
				zoom: @_zoom
			}
		}

		if @_isUseClusters()
			options.method = 'bankGeo/getClusters';
			options.params.region_id = @_region;

			delete(options.params.fields);

		@._sendAjax(options, @processData);

	#@method: buildGeoCollection
	#Create Geo Collection or Clusterer
	buildGeoCollection: () ->
		if @_isUseClusters() is true
			@_collection = new ymaps.GeoObjectCollection()
		else
			@_collection = new ymaps.Clusterer({
				gridSize: 128
				preset: "twirl#blackClusterIcons"
				margin: 25
				minClusterSize: 2
				clusterDisableClickZoom: false
				balloonShadow: false
			})

		@addToMap(@_collection)

	#@method: processData
	#Process points data
	processData: (result) ->
		if result? and result.data? and result.data.length > 0
			@_data = result.data
			if @_data.length > 500
				@processBigData()
			else
				@appendItemsToCollection(@_data)

		@setLoader(false)

	#@method: processBigData
	#Process big points data
	processBigData: () ->
		tmp = @_data.concat()

		setTimeout =>
			points = tmp.splice(0, 1000)
			@appendItemsToCollection(points)

			if tmp.length > 0
				setTimeout(arguments.callee, 25)
		, 25

	#@method: buildGeoObject
	#Create a Geo Object
	buildGeoObject: (object) ->
		if object.points_count? and object.points_count > 1
			size = 's';

			icon = ymaps.templateLayoutFactory.createClass('<div class="banks-geo__cluster banks-geo__cluster--$[properties.size]" data-type="$[properties.points]">$[properties.points]</div>', {
				build: () ->
					icon.superclass.build.call(@)
				clear: () ->
					icon.superclass.clear.call(@)
			})

			if object.points_count >= 1000
				size = 'b'
			else if object.points_count >= 10
				size = 'm'

			new ymaps.Placemark(
				[object.latitude, object.longitude],
				{
					size: size,
					points: object.points_count,
					iconContent: object.points_count
				}, {
					iconLayout: icon
				}
			)

		else
			icon = ymaps.templateLayoutFactory.createClass(
				'<div class="banks-geo__point $[properties.type] $[properties.main]" data-type="$[properties.type]">$[properties.icon_url]</div>'
				{
					build: () ->
						icon.superclass.build.call(@)
					clear: () ->
						icon.superclass.clear.call(@)
				}
			)

			new ymaps.Placemark(
				[object.latitude, object.longitude]
				{
					id: object['id']
					type: 'banks-geo__point--' + object.type
					main: if object.is_main is true then 'banks-geo__point--main' else ''
					icon_url: if object.icon_url? then '<img src="' + object.icon_url + '">' else ''
					hintContent: object.name
					balloonContent: object.address
				}, {
					hasHint: true
					iconLayout: icon
					balloonCloseButton: true
					balloonShadow: false
				}
			)

	#@method: appendItemsToCollection
	#Append Geo Objects to collection
	appendItemsToCollection: (objects) ->
		iterations = objects.length % 8
		i = objects.length - 1

		while iterations > 0
			@appendToCollection(@buildGeoObject(objects[i--]))
			iterations--

		iterations = Math.floor(objects.length / 8)

		while iterations > 0
			@appendToCollection(@buildGeoObject(objects[i--]))
			@appendToCollection(@buildGeoObject(objects[i--]))
			@appendToCollection(@buildGeoObject(objects[i--]))
			@appendToCollection(@buildGeoObject(objects[i--]))
			@appendToCollection(@buildGeoObject(objects[i--]))
			@appendToCollection(@buildGeoObject(objects[i--]))
			@appendToCollection(@buildGeoObject(objects[i--]))
			@appendToCollection(@buildGeoObject(objects[i--]))
			iterations--


	#@method: appendToCollection
	#Append Geo Object to collection
	appendToCollection: (object) ->
		if object?
			@_collection.add(object);

	setLoader: (state) ->
		if state? and state is true
			@_loader.show()
		else
			@_loader.hide()

	# Map functions
	addToMap: (object) ->
		if object?
			@_map.geoObjects.add(object)

	setCenter: (center, zoom) ->
		if center? and zoom?
			@_map.setCenter(center, zoom)

	setZoom: (zoom) ->
		if zoom?
			@_map.setCenter(zoom)

	# Halpers
	log: (message) ->
		if console?
			console.log message