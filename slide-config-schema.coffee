# #my-plugin configuration options
# Declare your config option for your plugin here. 
module.exports = {
  title: "Slide plugin options"
  type: "object"
  properties:
    email:
      description: "E-mail address of Slide account."
      type: "string"
      default: ""
    password:
      description: "Password of Slide account. NOTE: This is stored in plain text in your Pimatic config"
      type: "string"
      default: ""
    polling:
      description: "Interval in seconds for which the status of your Slides should be retrieved. Set to 0 to disable polling. Minimum of 300 seconds because of rate limiting."
      type: "number"
      default: 300
}
