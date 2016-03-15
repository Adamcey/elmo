class ELMO.Views.RepeatGroupFormView extends Backbone.View
  initialize: (options) ->
    @tmpl = options.tmpl
    @next_inst_num = parseInt(@$el.find('.qing-group-instances').data('count')) + 1

  events:
    'click .add-instance' : 'add_instance'
    'click .remove-instance': 'remove_instance'

  add_instance: (event) ->
    event.preventDefault()
    qing_group = $(event.target).closest('.qing-group')
    qing_group.find('.qing-group-instances').append(@tmpl.replace(/__INST_NUM__/g, @next_inst_num))
    @next_inst_num++

  remove_instance: (event) ->
    event.preventDefault()
    instance = $(event.target.closest('.qing-group-instance'))
    instance.remove()
