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
		}
		@_useCluster = true
		@_useMapControl = true

		if not container? and typeof container isnt "string"
			return @log @_messages.empty_map

		if not options? and typeof container isnt "object"
			return @log @_messages.empty_options

		unless options.center?
			return @log @_messages.empty_center

		unless options.zoom?
			return @log @_messages.empty_zoom

		if options.useCluster?
			@_useCluster = if options.useCluster is true then true else false

		if options.useMapControl?
			@_useMapControl = if options.useMapControl is true then true else false

		@container = '#' + container
		@$container = $(@container)
		@center = options.center
		@zoom = options.zoom

		if options.data?
			if typeof options.data == 'function'
				@log '1'

			if typeof options.data == 'object'
				@data = options.data

		if options.url?
			if typeof options.url == 'string'
				@url = options.url

		ymaps.ready(@init)

	#@method: init
	#Initialize Yandex Map and preprocess data
	init: () =>
		@log 'Initialize'

		@map = new ymaps.Map(@$container[0], {
			@center
			@zoom
		});

		if @_useMapControl is true
			@map.controls.add('zoomControl', { left: 5, top: 5 })

		@buildGeoCollection()
		@processData()
		@loadData()

		@addToMap(@collection)

	setData: (data) ->
		if not data? or typeof data isnt "object" or data.length is 0
			@log @_messages.bad_data
		else
			@data = data

	#@method: buildGeoCollection
	#Create Geo Collection or Clusterer
	buildGeoCollection: () ->
		if @_useCluster is true
			@collection = new ymaps.Clusterer({
				preset: 'twirl#blackClusterIcons'
			})
		else
			@collection = new ymaps.GeoObjectCollection()

	#@method: loadData
	#Load point data
	loadData: () ->
		if @url?
			$.ajax @url,
				dataType: 'json'
				error: (jqXHR, textStatus, errorThrown) =>
					@log "AJAX Error: #{textStatus}"
				success: (data, textStatus, jqXHR) =>
					@data = data
					@processData()

	#@method: processData
	#Process points data
	processData: () ->
		if @data? and @data.length > 0
			if @data.length > 500
				@processBigData()
			else
					@appendItemsToCollection(@data)

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
	#Create an Geo Object
	buildGeoObject: (object) ->
		icon = ymaps.templateLayoutFactory.createClass(
			'<div class="map__point $[properties.type] $[properties.main]" data-type="$[properties.type]">$[properties.icon_url]</div>'
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
					type: 'map__point--' + object.type
					main: if object.is_main is true then 'map__point--main' else ''
					icon_url: if object.icon_url? then '<img src="//banki.ru' + object.icon_url + '">' else ''
					hintContent: ''
				}, {
					hasHint: true,
					iconLayout: icon,
	#				balloonLayout: options.balloon,
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



	# Map functions
	addToMap: (object) ->
		@map.geoObjects.add(object)


	# Halpers
	log: (message) ->
		console.log message