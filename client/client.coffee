@selected_keywords = new ReactiveArray []
@selected_screen_names = new ReactiveArray []


Template.home.onCreated ->
    Meteor.subscribe 'people'

    @autorun -> Meteor.subscribe('screen_names', selected_keywords.array(), selected_screen_names.array())
    @autorun -> Meteor.subscribe('keywords', selected_keywords.array(), selected_screen_names.array())
    @autorun -> Meteor.subscribe('docs', selected_keywords.array(), selected_screen_names.array())

Template.view.onCreated ->
    Meteor.subscribe 'person', @authorId


Template.home.helpers
    doc_counter: -> Counts.get('doc_counter')
    user_counter: -> Meteor.users.find().count()

    global_keywords: -> Keywords.find()
    selected_keywords: -> selected_keywords.list()

    global_screen_names: -> Screennames.find()
    selected_screen_names: -> selected_screen_names.list()

    user: -> Meteor.user()
    docs: -> Docs.find()

    viewMyTweetsClass: -> if Meteor.user().profile.name in selected_screen_names.array() then 'active' else ''
    hasReceivedTweets: -> Meteor.user().hasReceivedTweets

Template.home.events
    'click .select_screen_name': -> selected_screen_names.push @text
    'click .unselect_screen_name': -> selected_screen_names.remove @valueOf()
    'click #clear_screen_names': -> selected_screen_names.clear()

    'click .select_keyword': -> selected_keywords.push @text
    'click .unselect_keyword': -> selected_keywords.remove @valueOf()
    'click #clear_keywords': -> selected_keywords.clear()

    # 'click .admin_pull': ->
        # Meteor.call 'get_tweets

    'click .clear_my_docs': -> Meteor.call 'clear_my_docs', ->
        Meteor.setTimeout (->
            selected_screen_names.clear()
            ), 1000

    'click .get_tweets': -> Meteor.call 'get_tweets', Meteor.user().profile.name, ->
        Meteor.setTimeout (->
            selected_screen_names.push Meteor.user().profile.name
            ), 1000

    'click .view_my_tweets': -> if Meteor.user().profile.name in selected_screen_names.array() then selected_screen_names.remove Meteor.user().profile.name else selected_screen_names.push Meteor.user().profile.name

    'click .tweetViewAuthorButton': -> if @screen_name in selected_screen_names.array() then selected_screen_names.remove @screen_name else selected_screen_names.push @screen_name

    'click .authorFilterButton': (event)->
        if event.target.innerHTML in selected_screen_names.array() then selected_screen_names.remove event.target.innerHTML else selected_screen_names.push event.target.innerHTML

Template.view.helpers
    doc_keyword_class: -> if @text.valueOf() in selected_keywords.array() then 'grey' else ''
    authorButtonClass: -> if @screen_name in selected_screen_names.array() then 'active' else ''

