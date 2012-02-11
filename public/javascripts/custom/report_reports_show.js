(function (report, undefined) {
  // === PRIVATE ===
  var RERUN_FIELDS = ["kind", "filter", "pri_grouping", "sec_grouping"];
  
  // === PUBLIC ===
  
  // public methods and properties  
  report.obj = {};
  report.form = {};

  // initializes things
  report.init = function() {
    // hook up buttons
    $j('#report_report_view_and_save').click(function(){view(true); return false;});
    $j('#report_report_view').click(function(){view(false); return false;});
    $j('#edit_form_link').click(function(){report.toggle_form(); return false;});
    
    // redraw report
    redraw();
  }
  
  // shows/hides the edit form
  report.toggle_form = function() {
    $j('#report_form').toggle();
    $j('#edit_form_link').text($j('#report_form').is(":visible") ? "Hide Edit Controls" : "Edit This Report")
  }
  
  report.show_success = function() {
    Utils.show_flash({type: "success", msg: "Report saved successfully.", hide_after: 3})
  }
  
  // === PRIVATE ===
  
  // decides whether to contact the server and redraws the report
  // save - whether the changes should be saved or only displayed
  function view(save) {
    // if save or rerun is required, send to server
    // otherwise just redraw
    var rerun = report.obj.errors || !report.obj.has_run || rerun_required();
    if (rerun || save)
      submit_to_server({save: save})
    else
      redraw();
  }

  // sends the report parameters to the server via ajax
  // options include:
  //   save: whether the parameters should be saved or not
  function submit_to_server(options) {
    var form = $j('#report_form form')[0];
    
    // show the loading indicator
    $j("#report_form div.loader").show();
    
    $j.ajax({
      type: 'POST',
      url: form.action,
      data: form.serialize() + "&save=" + !!options.save,
      success: function(data, status, jqxhr) {
        // show message if saved
        // if new data returned, save it
        if ($j.type(data) == "object") report.obj = data;
        
        // show success or error message
        if (report.obj.errors)
          Utils.show_flash({type: "error", msg: report.obj.errors})
        else if (options.save) {
          // if we're currently on the 'new' page, redirect to 'edit'
          if (window.location.pathname.match(/reports\/new/)) {
            window.location.href = "/report/reports/" + report.obj.id + "/edit?show_success=1";
            return;
          } else {
            report.show_success();
          }
        } else
          Utils.clear_flash()
        
        // always redraw on successful server request
        redraw();
        
        // hide the loading indicator
        $j("#report_form div.loader").hide();
      },
      error: function(jqxhr, status, error) {
        // display error
        Utils.show_flash({type: "error", msg: "Unknown error."})
      }
    })
  }

  // redraws the report
  function redraw() {
    // load current settings from form
    load_current_params();
  
    // if report has errors, don't show anything
    if (report.obj.errors) {
      $j('#report_body').empty().text("Could not display report.")

    } else if (!report.obj.has_run) {
      $j('#report_body').empty().text("Please use the controls on the left to create this report.");

    } else {
    
      var tbl = $j("<table>");
    
      // header row (only print if is at least one grouping)
      if (has_groupings()) {
        var trow = $j("<tr>");
    
        // blank cell in corner
        $j("<th>").appendTo(trow);
    
        // rest of header cells
        $j(report.obj.headers.col).each(function(idx, ch) {
          $j("<th>").addClass("col").text(ch || "[Null]").appendTo(trow);
        });
        tbl.append(trow);
      }
    
      // row total header
      if (show_totals("row"))
        $j("<th>").addClass("row_total").text("Total").appendTo(trow);
      
      // body
      $j(report.obj.headers.row).each(function(r, rh) {
        trow = $j("<tr>");
      
        // row header
        $j("<th>").addClass("row").text(rh || "[Null]").appendTo(trow);
      
        // row cells
        $j(report.obj.headers.col).each(function(c, ch) {
          $j("<td>").text(report.obj.data[r][c] || "").appendTo(trow);
        });
      
        // row total
        if (show_totals("row"))
          $j("<td>").addClass("row_total").text(report.obj.totals["row"][r]).appendTo(trow);

        tbl.append(trow);
      });
    
      // footer
      if (show_totals("col")) {
        trow = $j("<tr>");
      
        // row header
        $j("<th>").addClass("row").addClass("col_total").text("Total").appendTo(trow);
      
        // row cells
        $j(report.obj.totals.col).each(function(c, ct) {
          $j("<td>").addClass("col_total").text(ct > 0 ? ct : "").appendTo(trow);
        });
      
        // row total
        if (show_totals("row"))
          $j("<td>").addClass("row_total").addClass("col_total").text((gt = report.obj.grand_total) > 0 ? gt : "").appendTo(trow);

        tbl.append(trow);
      }
    
      $j('#report_body').empty().append(tbl);
    }

    // update the title
    set_title();
  }
  
  // checks whether total rows should be shown for a table report
  function show_totals(row_or_col) {
    return (row_or_col == "row") ? report.form.sec_grouping : report.form.pri_grouping
  }
  
  // updates the title of the report
  function set_title() {
    // set title
    $j("#content h1").text(report.form.name);
  }
  
  function load_current_params() {
    var fields = {
      kind: "kind", 
      name: "name",
      pri_grouping: "pri_grouping_attributes_form_choice",
      sec_grouping: "sec_grouping_attributes_form_choice", 
      filter: "filter_attributes_str"
    }
    $j.each(fields, function(attr, id){report.form[attr] = $j("#report_report_" + fields[attr]).val();});
  }
  
  // loads current paramteres from form
  // checks if the new values necessitate a re-run of the report
  function rerun_required() {
    // save old params
    var old_params = $j.extend({}, report.form);
    
    // load current paramters from form
    load_current_params();
    
    // for each parameter, if it has changed and changes require rerun, return true
    for (var k in old_params)
      if (old_params[k] != report.form[k] && RERUN_FIELDS.indexOf(k) != -1) 
        return true;
    
    // return false if get to this point
    return false;
  }
  
  // checks if the report has no groupings
  function has_groupings() {
    return report.form.pri_grouping || report.form.sec_grouping
  }

  // sends the report parameters to the server
  // along with an indication if the report should be run and/or if it should be saved 
  // if re-run is requested, report is redrawn on request completion
  // if request results in error, it is displayed and report is not redrawn
  function send() {
  
  }
}(report = {}));