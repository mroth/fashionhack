require 'sinatra'
require 'redis'
require 'slim'
require 'coffee-script'
require 'oj'

configure do
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  Oj.mimic_JSON
end
# configure :production do
#   require 'newrelic_rpm'
# end
conns = []

get '/' do
  slim :index
end

get '/application.js' do
  coffee :application
end

get '/data' do
  @rank = REDIS.zrevrange 'scores',0,19

  brand_details = []
  @rank.each do |brand|
    # REDIS.pipelined do
      @brand_score = REDIS.zscore "scores",brand
      @brand_image_count = REDIS.get "#{brand}_image_count"
      @brand_recent_tweets = REDIS.lrange "#{brand}_tweets",0,4
      @brand_recent_tweets.map! { |t| JSON.parse(t) }
      @brand_recent_images = REDIS.lrange "#{brand}_images",0,4
    # end
    brand_details << {name: brand, 
                        info: {
                          score: @brand_score, 
                          image_count: @brand_image_count, 
                          recent_tweets: @brand_recent_tweets,
                          recent_images: @brand_recent_images
                        }
                      }
  end

  content_type :json
  Oj.dump( {
    'rank'  => @rank,
    'details' => brand_details
  } )
end

get '/subscribe' do
  content_type 'text/event-stream'
  stream(:keep_open) do |out|
    conns << out
    out.callback { conns.delete(out) }
  end
end

# Thread.new do
#   uri = URI.parse(ENV["REDISTOGO_URL"])
#   redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

#   redis.psubscribe('stream.tweets.*') do |on|
#     on.pmessage do |match, channel, message|
#       type = channel.sub('stream.tweets.', '')

#       conns.each do |out|
#         out << "event: #{channel}\n"
#         out << "data: #{message}\n\n"
#       end
#     end
#   end

# end
