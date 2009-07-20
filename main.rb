require 'rubygems'
require 'sinatra'
require 'haml'
require 'sequel'

use Rack::Session::Cookie
gem 'rack-openid'
require 'rack/openid'
use Rack::OpenID

configure do
  require 'ostruct'
  Blog = OpenStruct.new( { :identity_url => 'http://subbarao.myopenid.com/',
    :title => "RuBy JavAsCriPt RaCk rAIls SinAtRa",
    :header => "",
    :disqus_shortname => nil,
    :admin_cookie_key => "scanty_admin",
    :admin_cookie_value => "51d6d976913ace58",
    :admin => nil
  } )
  DB = Sequel.connect(ENV['DATABASE_URL']||"sqlite://blog.db")
  unless DB.table_exists?(:posts)
    DB.create_table :posts  do
      primary_key :id
      text :title
      text :body
      text :slug
      text :tags
      timestamp :created_at
    end #create_table
  end
end

error do
  e = request.env['sinatra.error']
  puts e.to_s
  puts e.backtrace.join("\n")
  "Application error"
end

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'post'

helpers do

  def partial(page, options={})
    haml page, options.merge!(:layout => false)
  end

  def admin?
    request.cookies[Blog.admin_cookie_key] == Blog.admin_cookie_value
  end

  def auth
    stop [ 401, 'Not authorized' ] unless admin?
  end
end

layout 'layout'

### Public

get '/' do
  posts = Post.reverse_order(:created_at).limit(10)
  haml  :index, :locals => { :posts => posts }
end

get '/past/:year/:month/:day/:slug/' do
  post = Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  @title = post.title
  haml :post, :locals => { :post => post }
end

get '/past/:year/:month/:day/:slug' do
  redirect "/past/#{params[:year]}/#{params[:month]}/#{params[:day]}/#{params[:slug]}/", 301
end

get '/past' do
  posts = Post.reverse_order(:created_at)
  @title = "Archive"
  haml :archive, :locals => { :posts => posts }
end

get '/past/tags/:tag' do
  tag = params[:tag]
  posts = Post.filter(:tags.like("%#{tag}%")).reverse_order(:created_at).limit(30)
  @title = "Posts tagged #{tag}"
  haml :tagged, :locals => { :posts => posts, :tag => tag }
end

get '/feed' do
  @posts = Post.reverse_order(:created_at).limit(10)
  content_type 'application/atom+xml', :charset => 'utf-8'
  builder :feed
end

get '/rss' do
  redirect '/feed', 301
end

get '/blog/feed.rss' do
  redirect '/feed', 301
end

### Admin


get '/posts/new' do
  auth
  haml :edit, :locals => { :post => Post.new, :url => '/posts' }
end

post '/posts' do
  auth
  post = Post.new :title => params[:title], :tags => params[:tags], :body => params[:body], :created_at => Time.now, :slug => Post.make_slug(params[:title])
  post.save
  redirect post.url
end

get '/past/:year/:month/:day/:slug/edit' do
  auth
  post = Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  haml :edit, :locals => { :post => post, :url => post.url }
end

post '/past/:year/:month/:day/:slug/' do
  auth
  post = Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  post.title = params[:title]
  post.tags = params[:tags]
  post.body = params[:body]
  post.save
  redirect post.url
end

get '/login' do
  haml :login
end

get '/logout' do
  set_cookie(Blog.admin_cookie_key, nil)
  session.clear
  [ 302, { 'Location' => '/' }, [] ]
end

post '/login' do
  if resp = request.env["rack.openid.response"]
    if resp.status == :success && request.env["rack.openid.response"].identity_url == Blog.identity_url
      set_cookie(Blog.admin_cookie_key, Blog.admin_cookie_value)
      redirect '/'
    else
      "Error: #{resp.status}"
    end
  else
    headers 'WWW-Authenticate' => Rack::OpenID.build_header(
    :identifier => params["openid_identifier"]
    )
    throw :halt, [401, 'got openid?']
  end
end
