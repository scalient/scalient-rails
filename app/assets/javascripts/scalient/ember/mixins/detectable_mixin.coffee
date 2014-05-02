((factory) ->
  if typeof define is "function" and define.amd?
    define ["ember"], factory
).call(@, (Ember) ->
  resolutionQuery = "only screen and (min-resolution: 192dpi),"
  resolutionQuery += " only screen and (min-resolution: 2dppx),"
  resolutionQuery += " only screen and (min-resolution: 75.6dpcm)"

  pixelRatioQuery = "only screen and (-webkit-min-device-pixel-ratio: 2),"
  pixelRatioQuery += " only screen and (-o-min-device-pixel-ratio: 2/1),"
  pixelRatioQuery += " only screen and (-moz-min-device-pixel-ratio: 2),"
  pixelRatioQuery += " only screen and (min-device-pixel-ratio: 2)"

  DetectableMixin = Ember.Mixin.create
    isRetinaDisplay: ->
      result = window.matchMedia?
      result &&= window.matchMedia(resolutionQuery).matches or window.matchMedia(pixelRatioQuery).matches
      result ||= window.devicePixelRatio? and window.devicePixelRatio >= 2

      result

  DetectableMixin
)
