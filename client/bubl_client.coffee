@selected_tags = new ReactiveArray []
@selected_screen_names = new ReactiveArray []


Template.home.onCreated ->
    Meteor.subscribe 'people'

    @autorun -> Meteor.subscribe('screen_names', selected_tags.array(), selected_screen_names.array())
    @autorun -> Meteor.subscribe('tags', selected_tags.array(), selected_screen_names.array())
    @autorun -> Meteor.subscribe('docs', selected_tags.array(), selected_screen_names.array())

Template.view.onCreated ->
    Meteor.subscribe 'person', @authorId


Template.home.helpers
    doc_counter: -> Counts.get('doc_counter')
    user_counter: -> Meteor.users.find().count()

    cloud_tag_class: ->
        buttonClass = switch
            when @index <= 10 then 'big'
            when @index <= 20 then 'large'
            when @index <= 30 then ''
            when @index <= 40 then 'small'
            when @index <= 50 then 'tiny'
        return buttonClass


    global_tags: -> Tags.find()
    selected_tags: -> selected_tags.list()

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

    'click .select_tag': -> selected_tags.push @text
    'click .unselect_tag': -> selected_tags.remove @valueOf()
    'click #clear_tags': -> selected_tags.clear()

    'click .clear_my_docs': -> Meteor.call 'clear_my_docs', ->
        Meteor.setTimeout (->
            selected_screen_names.clear()
            selected_tags.clear()
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
    doc_tag_class: -> if @valueOf() in selected_tags.array() then 'grey' else ''
    authorButtonClass: -> if @screen_name in selected_screen_names.array() then 'active' else ''
    is_author: -> @authorId is Meteor.userId()
    when: -> moment(@timestamp).fromNow()
    bubl_tags: -> _.without(@tags, 'bubl', 'tweet')

Template.view.events
    'click .delete_tweet': -> Docs.remove @_id
    'click .doc_tag': -> if @valueOf() in selected_tags.array() then selected_tags.remove @valueOf() else selected_tags.push @valueOf()
