request = require("request")
_ = require("underscore")
npmPackage = require('./../package.json')

module.exports = class LookerAPIClient

  constructor: (@options) ->
    @fetchAccessToken()

  reachable: ->
    @token?

  request: (requestConfig, successCallback, errorCallback) ->
    unless @reachable()
      errorCallback({error: "Looker #{@options.baseUrl} not reachable"})
      return

    requestConfig.url = "#{@options.baseUrl}/#{requestConfig.path}"
    headers =
      Authorization: "token #{@token}"
      "User-Agent": "looker-slackbot/#{npmPackage.version}"
    requestConfig.headers = _.extend(headers, requestConfig.headers || {})
    request(requestConfig, (error, response, body) =>
      if error
        errorCallback?(error)
      else if response.statusCode == 200
        if response.headers['content-type'].indexOf("application/json") != -1
          successCallback?(JSON.parse(body))
        else
          successCallback?(body)
      else
        try
          errorCallback?(JSON.parse(body))
        catch
          console.error("JSON parse failed:")
          console.error(body)
          errorCallback({error: "Couldn't parse Looker response. The server may be offline."})
    )

  get: (path, successCallback, errorCallback, options = {}) ->
    @request(_.extend({method: "GET", path: path}, options), successCallback, errorCallback)

  post: (path, body, successCallback, errorCallback) ->
    @request(
      {
        method: "POST"
        path: path
        body: JSON.stringify(body)
        headers:
          "content-type": "application/json"
      },
      successCallback,
      errorCallback
    )

  fetchAccessToken: ->

    options =
      method: "POST"
      url: "#{@options.baseUrl}/login"
      form:
        client_id: @options.clientId
        client_secret: @options.clientSecret

    request(options, (error, response, body) =>
      if error
        console.warn("Couldn't fetchAccessToken for Looker #{@options.baseUrl}: #{error}")
        @token = null
      else if response.statusCode == 200
        json = JSON.parse(body)
        @token = json.access_token
        console.log("Updated API token for #{@options.baseUrl}")
      else
        @token = null
        console.warn("Failed fetchAccessToken for Looker #{@options.baseUrl}: #{body}")
      @options.afterConnect?()
    )
