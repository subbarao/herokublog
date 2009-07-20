require 'rubygems'
require 'sinatra'
require 'main'

set :environment, :production
run Sinatra::Application
