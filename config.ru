# This is a Rack configuration file for the Colleague web interface
require 'bundler/setup'

# Add the lib directory to the load path so Ruby can find our code
lib_path = File.expand_path('./lib', __dir__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'colleague'
require 'colleague/web'

# Run the Colleague web application
run Colleague::Web