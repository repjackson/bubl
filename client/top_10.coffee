Template.top_10.onCreated ->
    # @autorun -> Meteor.subscribe('top_10', selected_tags.array())
    @autorun -> Meteor.subscribe('top_10', Session.get('tag_selection'))

    
    
Template.top_10.helpers
    tag_selection: -> Session.get 'tag_selection'
    top_10_list: ->
        tag = Session.get 'tag_selection'
        author_ranking = []
        authors = Authors.find().fetch()
        for author in authors
            # console.log author
            user_tag_count = _.findWhere(author.authored_cloud, name: tag)?.count
            console.log 'user_tag_count', user_tag_count?.count
            author_ranking.push
                leader_username: author.username
                leader_tag_count: user_tag_count
        # console.log author_ranking
        sorted_list = _.sortBy(author_ranking, 'leader_tag_count').reverse()
        # clipped_list = []
        # for item in sorted_list
        #     # console.log item
        #     clipped_list.push
        #         matchedUser: item.matchedUser
        #         tagIntersection: item.tagIntersection.slice(0,5)
        #         length: item.length
    
        console.log(item) for item in sorted_list
        # return clipped_list
        return sorted_list

