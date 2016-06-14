

Meteor.methods
    get_tweets: (screen_name)->
        twitterConf = ServiceConfiguration.configurations.findOne(service: 'twitter')
        twitter = Meteor.user().services.twitter

        Twit = new TwitMaker(
            consumer_key: twitterConf.consumerKey
            consumer_secret: twitterConf.secret
            access_token: twitter.accessToken
            access_token_secret: twitter.accessTokenSecret
            app_only_auth:true)

        Twit.get 'statuses/user_timeline', {
            screen_name: screen_name
            count: 200
            include_rts: true
            exclude_replies: false
        }, Meteor.bindEnvironment(((err, data, response) ->
            for tweet in data
                # console.log tweet
                id = Docs.insert
                    authorId: Meteor.userId()
                    tags: ['bubl','tweet']
                    body: tweet.text
                    screen_name: screen_name
                    timestamp: Date.now()
                    tweet_created_at: tweet.created_at
                # Meteor.call 'alchemy_tag', id, tweet.text, ->
                #     console.log 'alchemy was run'
                Meteor.call 'yaki_tag', id, tweet.text
            ))

        # if screen_name is Meteor.user().profile.name
        Meteor.users.update Meteor.userId,
            $set: hasReceivedTweets: true

    yaki_tag: (id, body)->
        doc = Docs.findOne id
        suggested_tags = Yaki(body).extract()
        cleaned_suggested_tags = Yaki(suggested_tags).clean()
        uniqued = _.uniq(cleaned_suggested_tags)
        lowered = uniqued.map (tag)-> tag.toLowerCase()

        #lowered = tag.toLowerCase() for tag in uniqued

        Docs.update id,
            # $set: yaki_tags: lowered
            $addToSet: tags: $each: lowered


    # alchemy_tag: (id, body)->
    #     doc = Docs.findOne id
    #     encoded = encodeURIComponent(body)

    #     # result = HTTP.call 'POST', 'http://gateway-a.watsonplatform.net/calls/text/TextGetCombinedData', { params:
    #     HTTP.call 'POST', 'http://access.alchemyapi.com/calls/html/HTMLGetCombinedData', { params:
    #         apikey: '6656fe7c66295e0a67d85c211066cf31b0a3d0c8'
    #         # text: encoded
    #         html: body
    #         outputMode: 'json'
    #         # extract: 'entity,keyword,title,author,taxonomy,concept,relation,pub-date,doc-sentiment' }
    #         extract: 'keyword' }
    #         , (err, result)->
    #             if err then console.log err
    #             else
    #                 keyword_array = _.pluck(result.data.keywords, 'text')

    #                 Docs.update id,
    #                     $set: alchemy_tags: keyword_array
    #                     $addToSet: tags: $each: keyword_array

    clear_my_docs: ->
        Docs.remove({screen_name: Meteor.user().profile.name})

        Meteor.users.update Meteor.userId(),
            $set: hasReceivedTweets: false


Docs.allow
    insert: (userId, doc)-> userId
    update: (userId, doc)-> doc.authorId is Meteor.userId()
    remove: (userId, doc)-> doc.authorId is Meteor.userId()


Meteor.publish 'docs', (selected_tags, selected_screen_names)->
    Counts.publish(this, 'doc_counter', Docs.find(), { noReady: true })

    match = {}
    match.tags = $all: ['bubl']
    if selected_tags.length > 0 then match.tags = $all: selected_tags
    if selected_screen_names.length > 0 then match.screen_name = $in: selected_screen_names

    Docs.find match,
        limit: 20

Meteor.publish 'doc', (id)-> Docs.find id

Meteor.publish 'people', -> Meteor.users.find {}

Meteor.publish 'person', (id)-> Meteor.users.find id

Meteor.publish 'screen_names', (selected_tags, selected_screen_names)->
    self = @

    match = {}
    match.tags = $all: ['bubl']
    if selected_tags.length > 0 then match.keyword_array = $all: selected_tags
    if selected_screen_names.length > 0 then match.screen_name = $in: selected_screen_names

    cloud = Docs.aggregate [
        { $match: match }
        { $project: screen_name: 1 }
        { $group: _id: '$screen_name', count: $sum: 1 }
        { $match: _id: $nin: selected_screen_names }
        { $sort: count: -1, _id: 1 }
        { $limit: 50 }
        { $project: _id: 0, text: '$_id', count: 1 }
        ]

    cloud.forEach (screen_name) ->
        self.added 'screen_names', Random.id(),
            text: screen_name.text
            count: screen_name.count
    self.ready()


Meteor.publish 'tags', (selected_tags, selected_screen_names)->
    self = @

    match = {}
    match.tags = $all: ['bubl']
    if selected_tags.length > 0 then match.tags = $all: selected_tags
    if selected_screen_names.length > 0 then match.screen_name = $in: selected_screen_names

    cloud = Docs.aggregate [
        { $match: match }
        { $project: tags: 1 }
        { $unwind: '$tags' }
        { $group: _id: '$tags', count: $sum: 1 }
        { $match: _id: $nin: selected_tags }
        { $sort: count: -1, _id: 1 }
        { $limit: 50 }
        { $project: _id: 0, text: '$_id', count: 1 }
        ]

    cloud.forEach (tag) ->
        self.added 'tags', Random.id(),
            text: tag.text
            count: tag.count

    self.ready()