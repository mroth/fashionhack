require 'rubygems'
require 'tweetstream'
require 'oj'
require 'colored'
require 'redis'
require 'uri'

# configure tweetstream instance
TweetStream.configure do |config|
  config.consumer_key       = ENV['CONSUMER_KEY']
  config.consumer_secret    = ENV['CONSUMER_SECRET']
  config.oauth_token        = ENV['OAUTH_TOKEN']
  config.oauth_token_secret = ENV['OAUTH_TOKEN_SECRET']
  config.auth_method = :oauth
end

# db setup
uri = URI.parse(ENV["REDISTOGO_URL"])
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

# my options
VERBOSE = ENV["VERBOSE"] || false

#setup
$stdout.sync = true
log = Logger.new(STDOUT)
log.level = Logger::DEBUG

#TODO: load terms from json
#TODO: create name->twitter hash map
TERMS = ["#fashionhack","@dkny", "@DVF", "@prabalgurung", "@MarcJacobsIntl", "@RebeccaMinkoff", "@MichaelKors", "@rag_bone"]

puts "Setting up a stream to track terms '#{TERMS}'..."
@client = TweetStream::Client.new
@client.on_error do |message|
  # Log your error message somewhere
  puts "ERROR: #{message}"
end
@client.on_limit do |skip_count|
  # do something
  puts "RATE LIMITED LOL"
end
@client.track(TERMS) do |status|
  puts " ** @#{status.user.screen_name}: ".green + status.text.white if VERBOSE
  status_small = {
    :id => status.id.to_s,
    :text => status.text,
    :username => status.user.screen_name
  }
  status_json = Oj.dump(status_small)

  #try to detect images
  detected_images = []
  status.urls.each do |url|
    url = url.expanded_url
    url_is_image = true ? url.end_with?(".jpg",".jpeg",".gif",".png") : false
    log.debug "   -> detected url: #{url}"
    log.debug "   -> OMG ITS AN IMAGE!" if url_is_image
    detected_images << url if url_is_image
  end

  #figure out which term we matched
  #TODO normalize terms to twitter
  
  matched_terms = []
  TERMS.each do |term|
   matched_terms.push(term) if status.text.include? term
  end

  #for each matched term, push to the results
  matched_terms.each do |term|
    # REDIS.INCR "#{term}_count" #TODO: can be deprecated with scores set...
    REDIS.pipelined do
      REDIS.ZINCRBY "scores",1,term
      REDIS.PUBLISH "#{term}_stream", status_json
      REDIS.LPUSH "#{term}_tweets", status_json
      REDIS.LTRIM "#{term}_tweets",0,9
    end

    detected_images.each do |img|
      REDIS.INCR "#{term}_image_count"
      REDIS.LPUSH "#{term}_images", img
      REDIS.LTRIM "#{term}_images",0,9
    end
  end

end
