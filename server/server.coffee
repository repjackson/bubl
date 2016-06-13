

Meteor.methods
    get_tweets: (screen_name)->
        if not screen_name
            console.error 'No screen name provided'
            return false


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
            include_rts: false
        }, Meteor.bindEnvironment(((err, data, response) ->
            for tweet in data
                id = Docs.insert
                    body: tweet.text
                    screen_name: screen_name
                Meteor.call 'analyze', id, tweet.text
            ))

        if screen_name is Meteor.user().profile.name
            Meteor.users.update Meteor.userId,
                $set: hasReceivedTweets: true

    analyze: (id, body)->
        doc = Docs.findOne id
        encoded = encodeURIComponent(body)

        # result = HTTP.call 'POST', 'http://gateway-a.watsonplatform.net/calls/text/TextGetCombinedData', { params:
        HTTP.call 'POST', 'http://access.alchemyapi.com/calls/html/HTMLGetCombinedData', { params:
            apikey: '6656fe7c66295e0a67d85c211066cf31b0a3d0c8'
            # text: encoded
            html: body
            outputMode: 'json'
            # extract: 'entity,keyword,title,author,taxonomy,concept,relation,pub-date,doc-sentiment' }
            extract: 'keyword,taxonomy,concept,doc-sentiment' }
            , (err, result)->
                if err then console.log err
                else
                    keyword_array = _.pluck(result.data.keywords, 'text')
                    concept_array = _.pluck(result.data.concepts, 'text')

                    Docs.update id,
                        $set:
                            docSentiment: result.data.docSentiment
                            language: result.data.language
                            keywords: result.data.keywords
                            concepts: result.data.concepts
                            entities: result.data.entities
                            taxonomy: result.data.taxonomy
                            keyword_array: keyword_array
                            concept_array: concept_array


    clear_my_docs: ->
        Docs.remove({screen_name: Meteor.user().profile.name})

        Meteor.users.update Meteor.userId(),
            $set: hasReceivedTweets: false


Docs.allow
    insert: (userId, doc)-> userId
    update: (userId, doc)-> doc.authorId is Meteor.userId()
    remove: (userId, doc)-> doc.authorId is Meteor.userId()


Meteor.publish 'docs', (selected_keywords, selected_concepts, selected_screen_names)->
    Counts.publish(this, 'doc_counter', Docs.find(), { noReady: true })

    match = {}
    if selected_keywords.length > 0 then match.keyword_array = $all: selected_keywords
    if selected_concepts.length > 0 then match.concept_array = $all: selected_concepts
    if selected_concepts.length > 0 then match.concept_array = $all: selected_concepts
    if selected_screen_names.length > 0 then match.screen_name = $in: selected_screen_names

    Docs.find match,
        limit: 20

Meteor.publish 'doc', (id)-> Docs.find id

Meteor.publish 'people', -> Meteor.users.find {}

Meteor.publish 'person', (id)-> Meteor.users.find id

Meteor.publish 'screen_names', (selected_keywords, selected_concepts, selected_screen_names)->
    self = @

    match = {}
    if selected_keywords.length > 0 then match.keyword_array = $all: selected_keywords
    if selected_concepts.length > 0 then match.concept_array = $all: selected_concepts
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


Meteor.publish 'keywords', (selected_keywords, selected_concepts, selected_screen_names)->
    self = @

    match = {}
    if selected_keywords.length > 0 then match.keyword_array = $all: selected_keywords
    if selected_concepts.length > 0 then match.concept_array = $all: selected_concepts
    if selected_screen_names.length > 0 then match.screen_name = $in: selected_screen_names

    cloud = Docs.aggregate [
        { $match: match }
        { $project: keywords: 1 }
        { $unwind: '$keywords' }
        { $group: _id: '$keywords.text', count: $sum: 1 }
        { $match: _id: $nin: selected_keywords }
        { $sort: count: -1, _id: 1 }
        { $limit: 50 }
        { $project: _id: 0, text: '$_id', count: 1 }
        ]

    cloud.forEach (keyword) ->
        self.added 'keywords', Random.id(),
            text: keyword.text
            count: keyword.count

    self.ready()

Meteor.publish 'concepts', (selected_concepts, selected_keywords, selected_screen_names)->
    self = @

    match = {}
    if selected_keywords.length > 0 then match.keyword_array = $all: selected_keywords
    if selected_concepts.length > 0 then match.concept_array = $all: selected_concepts
    if selected_screen_names.length > 0 then match.screen_name = $in: selected_screen_names

    cloud = Docs.aggregate [
        { $match: match }
        { $project: concepts: 1 }
        { $unwind: '$concepts' }
        { $group: _id: '$concepts.text', count: $sum: 1 }
        { $match: _id: $nin: selected_concepts }
        { $sort: count: -1, _id: 1 }
        { $limit: 50 }
        { $project: _id: 0, text: '$_id', count: 1 }
        ]

    cloud.forEach (concept) ->
        self.added 'concepts', Random.id(),
            text: concept.text
            count: concept.count

    self.ready()
