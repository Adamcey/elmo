// ELMO.App
//
// handles general client side stuff that appears in the template (e.g. language chooser form)
(function(ns, klass) {

  // constructor
  ns.App = klass = function(params) { var self = this;
    self.params = params;
    
    // setup I18n module
    I18n.locale = self.params.locale;
    I18n.defaultLocale = self.params.default_locale;
    I18n.fallbacks = true;

    // setup the language change form and link
    $("a#locale_form_link").on("click", function(){ $("#locale_form").css("display", "inline-block"); $(this).hide(); return false; });
    $("#locale_form select").on("change", function(){ self.change_locale($(this).val()); return false; });
    
    // set session countdown
    self.reset_session_countdown();
    
    // listen for any ajax calls so we can update the session countdown
    // but don't update the countdown if the auto param is set, because those don't count
    $(document).bind("ajaxComplete", function(event, xhr, ajaxopts){ 
      if (!ajaxopts.url.match(/\bauto=1\b/))
        self.reset_session_countdown(); 
    });
  }
  
  // sets a countdown to session timeout
  klass.prototype.reset_session_countdown = function() { var self = this;
    if (self.params.logged_in) {
      // clear the old one
      if (self.session_countdown) clearTimeout(self.session_countdown);
    
      // set the new one (subtract 5s to account for transit times)
      self.session_countdown = setTimeout(function(){ self.redirect_to_login(); }, self.params.session_timeout * 1000 - 5000);
    }
  }
  
  // redirects the user to the login page
  klass.prototype.redirect_to_login = function() { var self = this;
    window.location.href = self.params.login_path;
  }

  // changes the current locale by rewriting the url to use the new locale
  klass.prototype.change_locale = function(new_locale) { var self = this;    
    // build a new url and go there
    window.location.href = Utils.build_path(Utils.strip_path(window.location.pathname), {locale: new_locale});
  }
  
  // sets the title in h1#title and <title>
  klass.prototype.set_title = function(title) { var self = this;
    $("title").text(self.params.site_name + ": " + title)
    $("h1.title").text(title);
  }
})(ELMO);
