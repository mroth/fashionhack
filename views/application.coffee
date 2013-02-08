###
methods related to the polling UI
###
@refreshUIFromServer = ->
  $.get('/data', (response) -> 
    refreshLeaderboard response.details
    refreshImages response.latest_images
  , "json")

refreshImages = (latest_images) ->
  il=$("#latest_images ul")
  il.hide()
  il.empty()
  for image in latest_images
    il.append("<li style='display:inline; list-style-type: none;
'><a href='#{image.image}'><img src='#{image.image}/media?size=t' title='#{image.name}' alt='#{image.name}'></a></li>")
  il.fadeIn()

refreshLeaderboard = (details) ->
  ll=$("#leaderboard ol")
  ll.hide()
  ll.empty()
  for brand in details
    ll.append("
      <li>
        #{brand.name} (#{brand.info.score})<br/>
        #{formattedTweet(brand.info.recent_tweets[0])}
      </li>")
  ll.fadeIn()

###
methods related to the streaming UI
NONE OF THIS BEING USED IN CURRENT APP LEFTOVER FROM GOODVSEVIL BUT HERE TILL I CAN STEAL FROM
###
@startStreaming = ->
  @source = new EventSource('/subscribe')
  @source.addEventListener('stream.tweets.cat', processCatEvent, false)
  @source.addEventListener('stream.tweets.dog', processDogEvent, false)

@stopStreaming = ->
  @source.close()

processCatEvent = (event) -> updateUIfromStream 'cat', event.data
processDogEvent = (event) -> updateUIfromStream 'dog', event.data

updateUIfromStream = (animal, data) ->
  appendTweetList(animal, $.parseJSON(data) )
  incrementCountUI(animal)

appendTweetList = (animal, tweet) ->
  type = '#' + animal + '_tweets'
  selector = "#{type} ul#tweets"
  list_elements = $("#{selector} li")
  list_elements.first().remove() if list_elements.size() > 10
  $(selector).append( formattedTweet(tweet) )

incrementCountUI = (animal) ->
  count_selector = $("\##{animal}_count #count")
  count = parseInt count_selector.text()
  count_selector.text ++count

###
general purpose UI helpers
###
formattedTweet = (tweet) ->
  tweet_url = "http://twitter.com/#{tweet.username}/status/#{tweet.id}"
  "<span class='tweet'><strong>@#{tweet.username}:</strong> #{tweet.text} <a href='#{tweet_url}'>\#</a></span>"

@startRefreshTimer = ->
  # refreshUIFromServer()
  @refreshTimer = setInterval refreshUIFromServer, 9000

@stopRefreshTimer = ->
  clearInterval(@refreshTimer)

@streamingToggled = ->
  now_enabled = $('#stream_enabled_checkbox').is(':checked')

  if now_enabled
    console.log 'ENABLING STREAMING MODE'
    stopRefreshTimer()
    refreshUIFromServer()
    startStreaming()
    # $('body').animate( {backgroundColor: '#eee'}, "fast")
  else
    console.log 'DISABLING STREAMING MODE'
    stopStreaming()
    refreshUIFromServer()
    startRefreshTimer()
    # $('body').animate( {backgroundColor: '#fff'}, "fast")

$ ->
  setTimeout(refreshUIFromServer, 1)
  startRefreshTimer()

