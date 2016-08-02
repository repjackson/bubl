

Meteor.methods
    sync_tweets: (username)->
        twitterConf = ServiceConfiguration.configurations.findOne(service: 'twitter')
        twitter = Meteor.user().services.twitter

        Twit = new TwitMaker(
            consumer_key: twitterConf.consumerKey
            consumer_secret: twitterConf.secret
            access_token: twitter.accessToken
            access_token_secret: twitter.accessTokenSecret
            app_only_auth:true)

        Twit.get 'statuses/user_timeline', {
            screen_name: username
            count: 200
            include_rts: true
            exclude_replies: false
        }, Meteor.bindEnvironment(((err, data, response) ->
            for tweet in data
                # console.log tweet
                found_tweet = Docs.findOne(tweet.id_str)
                if found_tweet
                    console.log 'found duplicate ', tweet.id_str
                    continue
                else
                    id = Docs.insert
                        _id: tweet.id_str
                        entities: tweet.entities
                        # tags: ['bubl','tweet']
                        body: tweet.text
                        username: username
                        timestamp: Date.now()
                        tweet_created_at: tweet.created_at
                    Meteor.call 'alchemy_tag', id, tweet.text, ->
                        console.log 'alchemy was run'
                    Meteor.call 'yaki_tag', id, tweet.text
            existing_author = Authors.findOne username:username
            if existing_author then Meteor.call 'generate_author_cloud', username
            else
                Authors.insert username: username,
                    -> 
                        Meteor.call 'generate_author_cloud', username
            ))

    sync_instagram: (username)->
        twitterConf = ServiceConfiguration.configurations.findOne(service: 'instagram')
        instagram = Meteor.user().services.instagram

        console.log instagram
        # Twit = new TwitMaker(
        #     consumer_key: twitterConf.consumerKey
        #     consumer_secret: twitterConf.secret
        #     access_token: twitter.accessToken
        #     access_token_secret: twitter.accessTokenSecret
        #     app_only_auth:true)

        # Twit.get 'statuses/user_timeline', {
        #     screen_name: username
        #     count: 200
        #     include_rts: true
        #     exclude_replies: false
        # }, Meteor.bindEnvironment(((err, data, response) ->
        #     for tweet in data
        #         # console.log tweet
        #         found_tweet = Docs.findOne(tweet.id_str)
        #         if found_tweet
        #             console.log 'found duplicate ', tweet.id_str
        #             continue
        #         else
        #             id = Docs.insert
        #                 _id: tweet.id_str
        #                 entities: tweet.entities
        #                 # tags: ['bubl','tweet']
        #                 body: tweet.text
        #                 username: username
        #                 timestamp: Date.now()
        #                 tweet_created_at: tweet.created_at
        #             Meteor.call 'alchemy_tag', id, tweet.text, ->
        #                 console.log 'alchemy was run'
        #             Meteor.call 'yaki_tag', id, tweet.text
        #     existing_author = Authors.findOne username:username
        #     if existing_author then Meteor.call 'generate_author_cloud', username
        #     else
        #         Authors.insert username: username,
        #             -> 
        #                 Meteor.call 'generate_author_cloud', username
        #     ))


    yaki_tag: (id, body)->
        doc = Docs.findOne id
        suggested_tags = Yaki(body).extract()
        cleaned_suggested_tags = Yaki(suggested_tags).clean()
        uniqued = _.uniq(cleaned_suggested_tags)
        lowered = uniqued.map (tag)-> tag.toLowerCase()

        #lowered = tag.toLowerCase() for tag in uniqued

        Docs.update id,
            $set: yaki_tags: lowered
            $addToSet: tags: $each: lowered


    alchemy_tag: (id, body)->
        doc = Docs.findOne id
        encoded = encodeURIComponent(body)

        # result = HTTP.call 'POST', 'http://gateway-a.watsonplatform.net/calls/text/TextGetCombinedData', { params:
        HTTP.call 'POST', 'http://access.alchemyapi.com/calls/html/HTMLGetCombinedData', { params:
            apikey: '6656fe7c66295e0a67d85c211066cf31b0a3d0c8'
            # text: encoded
            html: body
            outputMode: 'json'
            # extract: 'entity,keyword,title,author,taxonomy,concept,relation,pub-date,doc-sentiment' }
            extract: 'keyword' }
            , (err, result)->
                if err then console.log err
                else
                    console.log 'alchemy result:', result
                    keyword_array = _.pluck(result.data.keywords, 'text')
                    lowered_keywords = keyword_array.map (tag)-> tag.toLowerCase()

                    Docs.update id,
                        $set: alchemy_tags: lowered_keywords
                        $addToSet: tags: $each: lowered_keywords

    clear_my_docs: ->
        Docs.remove({username: Meteor.user().profile.name})

    check_in: (location)->
        Meteor.users.update Meteor.userId(),
            $set: location: location

    generate_author_cloud: (username)->
        match = {}
        match.username = username
        console.log match
        authored_cloud = Docs.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $sort: count: -1, _id: 1 }
            { $limit: 10 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]
        console.log 'authored cloud', authored_cloud
        
        authored_list = (tag.name for tag in authored_cloud)
        
        Authors.update {username: username},
            $set:
                authored_cloud: authored_cloud
                authored_list: authored_list
            ,
                multi: false
                upsert: true

Meteor.publish 'top_10', (selected_tags)->
    # user_ranking = []
    # Authors.find({
    #     authored_list: $in: [tag]
    # })
    
    Authors.find({
        authored_list: $all: selected_tags
    })
    


Docs.allow
    insert: (userId, doc)-> userId
    update: (userId, doc)-> doc.authorId is Meteor.userId()
    remove: (userId, doc)-> doc.authorId is Meteor.userId()


Meteor.publish 'docs', (selected_tags, selected_screen_names)->
    Counts.publish(this, 'doc_counter', Docs.find(), { noReady: true })

    match = {}
    if selected_tags.length > 0 then match.tags = $all: selected_tags
    if selected_screen_names.length > 0 then match.screen_name = $in: selected_screen_names

    Docs.find match,
        limit: 10

Meteor.publish 'doc', (id)-> Docs.find id

Meteor.publish 'people', -> Meteor.users.find {}

Meteor.publish 'person', (id)-> Meteor.users.find id

Meteor.publish 'usernames', (selected_tags, selected_usernames)->
    self = @

    match = {}
    if selected_tags.length > 0 then match.keyword_array = $all: selected_tags
    # if selected_usernames.length > 0 then match.username = $in: selected_usernames

    cloud = Docs.aggregate [
        { $match: match }
        { $project: username: 1 }
        { $group: _id: '$username', count: $sum: 1 }
        { $match: _id: $nin: selected_usernames }
        { $sort: count: -1, _id: 1 }
        { $limit: 10 }
        { $project: _id: 0, text: '$_id', count: 1 }
        ]

    cloud.forEach (username) ->
        self.added 'usernames', Random.id(),
            text: username.text
            count: username.count
    self.ready()


Meteor.publish 'tags', (selected_tags, selected_usernames)->
    self = @
    # me = Meteor.users.findOne @userId
    # console.log me
    match = {}
    if selected_tags.length > 0 then match.tags = $all: selected_tags
    if selected_usernames.length > 0 then match.username = $in: selected_usernames
    # match.username = me.profile.name

    cloud = Docs.aggregate [
        { $match: match }
        { $project: tags: 1 }
        { $unwind: '$tags' }
        { $group: _id: '$tags', count: $sum: 1 }
        { $match: _id: $nin: selected_tags }
        { $sort: count: -1, _id: 1 }
        { $limit: 20 }
        { $project: _id: 0, text: '$_id', count: 1 }
        ]

    cloud.forEach (tag, i) ->
        self.added 'tags', Random.id(),
            text: tag.text
            count: tag.count
            index: i

    self.ready()
    
    
Meteor.publish 'people_tags', (selected_tags)->
    self = @
    match = {}
    if selected_tags?.length > 0 then match.tags = $all: selected_tags
    match._id = $ne: @userId

    tagCloud = Meteor.users.aggregate [
        { $match: match }
        { $project: "tags": 1 }
        { $unwind: "$tags" }
        { $group: _id: "$tags", count: $sum: 1 }
        { $match: _id: $nin: selected_tags }
        { $sort: count: -1, _id: 1 }
        { $limit: 50 }
        { $project: _id: 0, name: '$_id', count: 1 }
        ]

    tagCloud.forEach (tag, i) ->
        self.added 'people_tags', Random.id(),
            name: tag.name
            count: tag.count
            index: i

    self.ready()


# Meteor.publish 'me_as_author', ->
#     me = Meteor.users.findOne @userId
#     Authors.find username: me.profile.name