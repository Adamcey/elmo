// ELMO.Control.Multiselect
(function(ns, klass) {
  
  // constructor
  ns.Multiselect = klass = function(params) {
    var _this = this;
    this.params = params;

    this.fld = params.el;
    this.rebuild_options();
    this.dom_id = parseInt(Math.random() * 1000000);
    
    // hookup events
    this.fld.find(".links a.select_all").click(function() { _this.set_all(true); });
    this.fld.find(".links a.deselect_all").click(function() { _this.set_all(false); });
  }
  
  // inherit from Control
  klass.prototype = new ns.Control();
  klass.prototype.constructor = klass;
  klass.prototype.parent = ns.Control.prototype;
  
  klass.prototype.build_field = function () {
    
  }
  
  klass.prototype.rebuild_options = function() {
    var _this = this;
    
    // empty old rows
    this.fld.find(".choices").empty();
    this.rows = [];
    
    // add new rows
    for (var i = 0; i < this.params.objs.length; i++) {
      var id = this.params.objs[i][this.params.id_key];
      var txt = this.params.objs[i][this.params.txt_key];
      var row = $("<div>");
      var dom_id = this.dom_id + "_" + i;
      
      $("<input>").attr("type", "checkbox").attr("value", id).attr("id", dom_id).click(function(){ _this.handle_change(this); }).appendTo(row);
      $("<label>").attr("for", dom_id).html("&nbsp;" + txt).appendTo(row);
      
      this.rows.push(row);

      this.fld.find(".choices").append(row);
    }
  }
  
  klass.prototype.update = function(selected_ids) {
    // convert selected_ids to string
    for (var i = 0; i < selected_ids.length; i++)
      selected_ids[i] = selected_ids[i].toString();
      
    this.update_without_triggering(selected_ids);
    
    this.handle_change();
  }
  
  klass.prototype.change = function(func) {
    this.change_callback = func;
  }

  
  klass.prototype.update_without_triggering = function(selected_ids) {
    for (var i = 0; i < this.rows.length; i++) {
      var checked = selected_ids.indexOf(this.rows[i].find("input").attr("value")) != -1;
      this.rows[i].find("input").prop("checked", checked);
    }
  }
  
  klass.prototype.update_objs = function(objs) {
    this.params.objs = objs;
    var seld = this.get();
    this.rebuild_options();
    this.update_without_triggering(seld);
  }
  
  klass.prototype.get = function() {
    var seld = [];
    for (var i = 0; i < this.rows.length; i++)
      if (this.rows[i].find("input").prop("checked"))
        seld.push(this.rows[i].find("input").attr("value"));
    return seld;
  }
  
  klass.prototype.enable = function(which) {
    if (which)
      this.fld.find("input[type='checkbox']").removeAttr("disabled");
    else
      this.fld.find("input[type='checkbox']").attr("disabled", "disabled");
    this.fld.css("color", which ? "" : "#888");
  }
  
  klass.prototype.set_all = function(which) {
    for (var i = 0; i < this.rows.length; i++)
      this.rows[i].find("input").prop("checked", which);
    
    this.handle_change();
  }
  
  klass.prototype.handle_change = function() {
    this.toggle_select_all();
    if (this.change_callback) this.change_callback(this);
  }
  
  // checks if select all links should be toggled, and toggles them
  klass.prototype.toggle_select_all = function() {
    // check if the links are enabled at all
    if (this.fld.find(".links a.select_all")) {
      var all_checked = true;
      var any_checked = false;
      for (var i = 0; i < this.rows.length; i++) {
        if (this.rows[i].find("input").prop("checked"))
          any_checked = true;
        else
          all_checked = false;
          
        if (!all_checked && any_checked)
          break;
      }
    
      // show/hide select all links
      this.fld.find(".links a.select_all")[!all_checked ? "show" : "hide"]();
      this.fld.find(".links a.deselect_all")[any_checked ? "show" : "hide"]();
    }
  }
  
  klass.prototype.all_selected = function() {
    for (var i = 0; i < this.rows.length; i++)
      if (!this.rows[i].find("input").prop("checked"))
        return false;
    return true;
  }
  
}(ELMO.Control));