###
@author: Maxim Denisov (denisovmax1988@yandex.ru)
@date: 19/10/2013
@version: 0.1.1
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

		@_region = null
		@_serviceUrl = '/api/'
		@_ajaxCount = 0
		@_center = []
		@_zoom = 10
		@_regionName = ''
		@_regionIds = ['4', '211']

		@_useCluster = true
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

		@container = '#' + container
		@$container = $(@container)
		@center = options.center
		@zoom = options.zoom

		@$container.addClass('banks-geo').append('<div class="banks-geo__loader"/>')

		@loader = @$container.children('.banks-geo__loader')

		if options.data?
			if typeof options.data is 'function'
				@log '1'

			if typeof options.data is 'object'
				@data = options.data

		if options.url?
			if typeof options.url is 'string'
				@url = options.url

		@init()

	#@method: init
	#Initialize Yandex Map and preprocess data
	init: () =>
		if @._region?
			@getCenterByRegion()
		else
			@initMap()

	#@method: _getAjaxCount
	#Set point data
	_getAjaxCount: () ->
		@_ajaxCount++
		@_ajaxCount.toString()

	#@method: _sendAjax
	#Do ajax
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

	getCenterByRegion: () ->
		options = {
			method: 'region/get'
			params: {
				id: @._region
			}
		}

		@._sendAjax(options, @processMapOptions);

	processMapOptions: (result) ->
		if result.data?
			data = result.data
			@center = [data.latitude, data.longitude]
			@zoom = data.zoom

			@initMap()
		else
			@log @_messages.bad_response


	#@method: initMap
	#Initialize Yandex Map
	initMap: () ->
		ymaps.ready( () =>
			@map = new ymaps.Map(@$container[0], {
				@center
				@zoom
			});

			if @_useMapControl is true
				@map.controls.add('zoomControl', { left: 5, top: 5 })

			@buildGeoCollection()

			if @data? and @data.length > 0
				@processData({data: @data})
			else
				@getPointsData()
		)

	#@method: setData
	#Set point data
	setData: (data) ->
		if not data? or typeof data isnt "object" or data.length is 0
			@log @_messages.bad_data
		else
			@data = data

	#@method: getPointsData
	#Get point data
	getPointsData: () ->
		coords = @.map.getBounds()
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
			@collection = new ymaps.GeoObjectCollection()
		else
			@collection = new ymaps.Clusterer({
				gridSize: 128
				preset: "twirl#blackClusterIcons"
				margin: 25
				minClusterSize: 2
				clusterDisableClickZoom: false
				balloonShadow: false
			})

		@addToMap(@collection)

	#@method: processData
	#Process points data
	processData: (result) ->
		if result.data? and result.data.length > 0
			@data = result.data
			if @data.length > 500
				@processBigData()
			else
				@appendItemsToCollection(@data)

		@setLoader(false)

	#@method: processBigData
	#Process big points data
	processBigData: () ->
		tmp = @data.concat()

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
			);

		else
			icon = ymaps.templateLayoutFactory.createClass(
				'<div class="banks-geo__point $[properties.type] $[properties.main]" data-type="$[properties.type]">$[properties.icon_url]</div>'
			{
				build: () ->
					icon.superclass.build.call(@)
				clear: () ->
					icon.superclass.clear.call(@)
			})

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
			);

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
		@collection.add(object);

	setLoader: (state) ->
		if state? and state is true
			@loader.show()
		else
			@loader.hide()

	# Map functions
	addToMap: (object) ->
		@map.geoObjects.add(object)

	setCenter: (center, zoom) ->
		@map.setCenter(center, zoom)

	setZoom: (zoom) ->
		@map.setCenter(zoom)

	# Halpers
	log: (message) ->
		console.log message