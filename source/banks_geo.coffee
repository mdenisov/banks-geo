###
@author: Maxim Denisov (denisovmax1988@yandex.ru)
@date: 19/10/2013
@version: 0.1
@copyright: Banki.ru (www.banki.ru)
###

#BanksGeo = exports? and exports or @BanksGeo = {}

class BanksGeo

	#@method: constructor
	#Constructor
	constructor: (container, options) ->
		@_messages = {
			empty_map: 'Error: Empty map'
			empty_center: 'Error: Empty center'
			empty_zoom: 'Error: Empty zoom'
		}
		@useCluster = true
		@useMapControl = true

		unless container?
			return @log @_messages.empty_map

		unless options.center?
			return @log @_messages.empty_center

		unless options.zoom?
			return @log @_messages.empty_zoom

		if options.useCluster?
			@useCluster = if options.useCluster is true then true else false

		if options.useMapControl?
			@useMapControl = if options.useMapControl is true then true else false

		if container
			@container = '#' + container
			@$container = $(@container)
			@center = options.center
			@zoom = options.zoom

		if options.data?
			if typeof options.data == 'function'
				@log '1'

			if typeof options.data == 'object'
				@data = options.data

		ymaps.ready(@init)

	#@method: init
	#Initialize Yandex Map and preprocess data
	init: () =>
		@log 'Initialize'

		@map = new ymaps.Map(@$container[0], {
			@center
			@zoom
		});

		if @useMapControl is true
			@map.controls.add('zoomControl', { left: 5, top: 5 })

		@buildGeoCollection()
		@processData()

		@addToMap(@collection)

	#@method: buildGeoCollection
	#Create Geo Collection or Clusterer
	buildGeoCollection: () ->
		if @useCluster is true
			@collection = new ymaps.Clusterer({
				preset: 'twirl#blackClusterIcons'
			})
		else
			@collection = new ymaps.GeoObjectCollection()

	#@method: processData
	#Process point data
	processData: () ->
		if @data.length > 1
			for point in @data
				@appendToCollection(@buildGeoObject(point))

	#@method: buildGeoObject
	#Create an Geo Object
	buildGeoObject: (object) ->
		new ymaps.Placemark(object.coordinates, {

		})

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