Template.top_10.onCreated ->
    @autorun -> Meteor.subscribe('top_10', selected_tags.array())

    
    
Template.top_10.helpers
    top_10_list: (tag)->
        author_ranking = []
        authors = Authors.find()
        for author in authors
            user_tag_count = _.findWhere(author.authored_cloud, name: tag).count
            author_ranking.push
                leader_username: author.username
                leader_tag_count: user_tag_count
        console.log author_ranking
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

