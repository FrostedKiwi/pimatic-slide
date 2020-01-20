module.exports = (env) ->

	# Require the	bluebird promise library
	Promise = env.require 'bluebird'

	# Require the [cassert library](https://github.com/rhoot/cassert).
	assert = env.require 'cassert'

	rp = env.require 'request-promise'
	fs = env.require 'fs.extra'

	class SlidePlugin extends env.plugins.Plugin

		init: (app, @framework, @config) =>
			env.logger.info("Slide plugin loaded")

			packageInfo = JSON.parse fs.readFileSync(
				"./package.json", 'utf-8'
			)
			@userAgent = "Pimatic-Slide " + packageInfo.version

			deviceConfigDef = require("./device-config-schema")

			@framework.deviceManager.registerDeviceClass("SlideCurtains", {
				configDef: deviceConfigDef.SlideCurtains, 
				createCallback: (config) => new SlideCurtains(config, @)
			})

			@login(@config)


			@framework.deviceManager.on "discover", @onDiscover
                
		poll: =>
			options =
				uri: "https://api.goslide.io/api/slides/overview"
				method: "GET"
				headers:
					"User-Agent": @userAgent,
					Authorization: "Bearer " + @authKey
				json: true
				resolveWithFullResponse: true
				simple: false
			rp(options)
			.then((response) =>
				if response.statusCode == 200 || response.statusCode == 424
					data = response.body
					devices = @framework.deviceManager.getDevices()
					data.slides.forEach((slide) =>
						devices.forEach((device) =>
							if device.config.slideId == slide.id && slide.device_info.pos
								device._setDimlevel(slide.device_info.pos * 100)
						)
					)
				else
					env.logger.error("Slide API error: " + response.body.message)
			)
			.catch((err) =>
				env.logger.error(err)
			)

		login: (@config) =>
			plugin = this
			options =
				uri: "https://api.goslide.io/api/auth/login"
				method: "POST"
				headers:
					"User-Agent": @userAgent
				body:
					email: @config.email
					password: @config.password
				json: true
			rp(options)
			.then((data) =>
				@authKey = data.access_token
				setTimeout( ( => @login(@config) ), 7 * 24 * 60 * 60 * 1000)
				@poll()
				if (@config.polling > 0)
					if (@config.polling < 300)
						@config.polling = 300
					setInterval( ( => @poll() ), @config.polling * 1000)
				)
			.catch((err) =>
				env.logger.error("Slide API error: " + err)
			)

		onDiscover: (eventData) =>
			@framework.deviceManager.discoverMessage( "pimatic-slide", "Loading devices from Slide account")
			options =
				uri: "https://api.goslide.io/api/slides/overview"
				method: "GET"
				headers:
					"User-Agent": @userAgent,
					Authorization: "Bearer " + @authKey
				json: true
			rp(options)
			.then((data) =>
				data.slides.forEach((slide) =>
					isnew = not @framework.deviceManager.devicesConfig.some (deviceconf, iterator) =>
						deviceconf.slideId is slide.id
					if isnew
						config =
							class: "SlideCurtains"
							name: slide.device_name
							slideId: slide.id
						@framework.deviceManager.discoveredDevice( "pimatic-slide", "Slide: #{config.name}", config)
				)
			)
			.catch((err) =>
				env.logger.error("Slide API error: " + err.error.message)
			)
			@framework.deviceManager.discoverMessage( "pimatic-slide", "Loaded devices from Slide account")


	class SlideCurtains extends env.devices.DimmerActuator

		constructor: (@config, @plugin, lastState) ->
			@name = @config.name
			@id = @config.id
			@_dimlevel = lastState?.dimlevel?.value or 0
			@_state = lastState?.state?.value or off
			super()

		# Returns a promise that is fulfilled when done.
		changeDimlevelTo: (level) ->
			@_setDimlevel(level)
			options =
				uri: "https://api.goslide.io/api/slide/" + @config.slideId + "/position"
				method: "POST"
				headers:
					"User-Agent": @userAgent,
					Authorization: "Bearer " + @plugin.authKey
				body:
					pos: level / 100
				json: true
			rp(options)
			.then((data) =>
			)
			.catch((err) =>
				env.logger.error("Slide API error: " + err.error.message)
			)
			return Promise.resolve()

		destroy: () ->
			super()

	slide = new SlidePlugin
	return slide
