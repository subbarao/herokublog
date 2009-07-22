require 'rubygems'
require 'sinatra'
require 'haml'
require 'sequel'

use Rack::Session::Cookie
gem 'rack-openid'
require 'rack/openid'

gem 'subbarao-sinatra-openid'
require 'sinatra/openid'

set :admin_urls,%w( http://subbarao.myopenid.com )

use Rack::OpenID

configure do
  require 'ostruct'
  Blog = OpenStruct.new( { :identity_url => 'http://subbarao.myopenid.com/',
    :title => "RuBy JavAsCriPt RaCk rAIls SinAtRa",
    :header => "Learning grows on.......",
    :url_base => "http://subbarao.me/",
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
      boolean :published, :default => false
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

  def tags
    unless @tags.nil?
      list = @tags.inject("<span>") do |html, t|
        html << "<a href='/past/tags/#{t}'>#{t}</a> "
      end
      "#{list}</span>"
    end
  end

end

layout 'layout'

### Public

get '/' do
  @tags = Post.tags
  posts = Post.published_posts.reverse_order(:created_at).limit(10)
  haml  :index, :locals => { :posts => posts }
end

get '/drafts' do
  @tags = Post.tags
  posts = Post.filter(:published => false).reverse_order(:created_at).limit(10)
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
  posts = Post.published_posts.reverse_order(:created_at)
  @title = "Archive"
  haml :archive, :locals => { :posts => posts }
end

get '/past/tags/:tag' do
  tag = params[:tag]
  posts = Post.published_posts.filter(:tags.like("%#{tag}%")).reverse_order(:created_at).limit(30)
  @title = "Posts tagged #{tag}"
  haml :tagged, :locals => { :posts => posts, :tag => tag }
end

get '/feed' do
  @posts = Post.published_posts.reverse_order(:created_at).limit(10)
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
  authorize!
  haml :edit, :locals => { :post => Post.new, :url => '/posts' }
end

post '/posts' do
  authorize!
  post = Post.new :title => params[:title], :tags => params[:tags], :body => params[:body], :created_at => Time.now, :slug => Post.make_slug(params[:title])
  post.save
  redirect post.url
end

get '/past/:year/:month/:day/:slug/edit' do
  authorize!
  post = Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  haml :edit, :locals => { :post => post, :url => post.url }
end

post '/past/:year/:month/:day/:slug/' do
  authorize!
  post = Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  post.title = params[:title]
  post.tags = params[:tags]
  post.body = params[:body]
  post.save
  redirect post.url
end
