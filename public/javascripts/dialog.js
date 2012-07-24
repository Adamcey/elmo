// ELMO.Dialog
(function(ns) {
  
  // constructor
  ns.Dialog = klass = function(contents) {
    this.contents = contents;
    // create and add div
    this.bg = $("<div>").addClass("dialog_bg");
    this.bg.appendTo($("body")).after(this.contents.addClass("dialog"));
    $(window).resize(this.redraw);
    this.redraw();
  }
  
  klass.prototype.close = function() {
    this.bg.remove();
    this.contents.remove();
  }
  
  klass.prototype.redraw = function() {
    $("div.dialog_bg").width($(document).width()).height($(document).height());
    this.contents.css("top", ($(window).height() - this.contents.height()) / 2);
    this.contents.css("left", ($(window).width() - this.contents.width()) / 2);
  }
}(ELMO));