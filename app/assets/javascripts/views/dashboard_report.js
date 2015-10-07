// ELMO.Views.DashboardReport
//
// View model for the dashboard report
(function(ns, klass) {

  // constructor
  ns.DashboardReport = klass = function(dashboard, params) { var self = this;
    self.dashboard = dashboard;
    self.params = params;

    // save the report id
    if (params)
      self.current_report_id = self.params.id;

    // hookup the form change event
    self.hookup_report_chooser();
  };

  klass.prototype.hookup_report_chooser = function () { var self = this;
    $('.report_pane').on('change', 'form.report_chooser', function(e){
      var report_id = $(e.target).val();
      if (report_id) self.change_report(report_id);
    });
  };

  klass.prototype.refresh = function() {
    ELMO.app.report_controller.run_report().then(function(report){
      $('.report_pane h2').html(report.attribs.name);
    });
  };

  klass.prototype.change_report = function(id) { var self = this;
    // save the ID
    self.current_report_id = id;

    // show loading message
    $('.report_pane h2').html(I18n.t('report/report.loading_report'));

    // remove the old content and replace with new stuff
    $('.report_main').empty();
    $('.report_main').load(ELMO.app.url_builder.build('reports', id),
      function(){
        $('.report_pane h2').html(ELMO.app.report_controller.report_last_run.attribs.name);
      });

    // clear the dropdown for the next choice
    $('.report_chooser select').val("");
  };

  klass.prototype.reset_title_pane_text = function(title) {
    $('.report_title_text').text(title)
  };

  klass.prototype.set_edit_link = function(data) {
    if (data.user_can_edit) {
      report_url = ELMO.app.url_builder.build('reports', data.report.id) + '/edit';

      $('.report_edit_link_container').show();
      $('.report_edit_link_container a').attr('href', report_url)
    } else {
      $('.report_edit_link_container').hide();
      $('.report_edit_link_container a').attr('href', '')
    }
  };

}(ELMO.Views));
