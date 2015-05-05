class ELMO.Views.SettingsView extends Backbone.View

  el: 'form.setting_form'

  events:
    'click #external_sql .control a': 'select_external_sql'
    'click .adapter_settings a': 'show_change_password_fields'
    'click .using-incoming_sms_token': 'show_using_incoming_sms_token_modal'
    'change select#setting_outgoing_sms_adapter': 'show_adapter_settings'

  initialize: ->
    this.show_adapter_settings()

  select_external_sql: (event) ->
    $("form.setting_form #external_sql .control pre").selectText()
    return false

  show_change_password_fields: (event) ->
    $(event.target).hide()
    $(event.target).closest('.adapter_settings').find(".password_fields").show()
    return false

  show_using_incoming_sms_token_modal: (event) ->
    event.preventDefault()
    ELMO.app.loading(true)

    $.ajax
      url: ELMO.app.url_builder.build('settings', 'using_incoming_sms_token_message')
      success: (data) ->
        new ELMO.Views.UsingIncomingSmsTokenModalView({ html: data.message })
      complete: ->
        ELMO.app.loading(false)

  show_adapter_settings: (event) ->
    if (event)
      event.preventDefault()

    # first hide all
    this.$(".adapter_settings").hide()

    # get the current outgoing adapter
    adapter = this.$('select#setting_outgoing_sms_adapter').val()

    # then show the appropriate one (if any)
    if (adapter)
      this.$(".adapter_settings[data-adapter=" + adapter + "]").show()
