// ELMO.Models.OptioningCollection
//
// Client side optionings collection model
(function(ns, klass) {

  // constructor
  ns.OptioningCollection = klass = function(optioning_attribs) { var self = this;

    // create an array for removed optionings
    self.removed = [];

    self.dirty = false;

    // create model objects for each optioning hash
    self.optionings = optioning_attribs.map(function(optioning){
      optioning.option = new ELMO.Models.Option(optioning.option);
      optioning.parent = self;
      return new ELMO.Models.Optioning(optioning);
    });
  };

  // adds an optioning to the set
  klass.prototype.add = function(optioning) { var self = this;
    optioning.parent = self;
    self.optionings.push(optioning);
    self.dirty = true;
  };

  // removes a given optioning from the set
  klass.prototype.remove = function(optioning) { var self = this;
    var removed = self.optionings.splice(self.optionings.indexOf(optioning), 1);

    // if the removed optioning has an id, save it as it will need to be destroyed
    if (removed[0].id)
      self.removed.push(removed[0]);

    self.dirty = true;
  };

  // checks if this set currently has an option with the given name
  klass.prototype.has_with_name = function(name) { var self = this;
    for (var i = 0; i < self.optionings.length; i++)
      if (self.optionings[i].translation(I18n.defaultLocale) == name)
        return true;
    return false;
  };

  klass.prototype.get = function() { var self = this;
    return self.optionings;
  };

})(ELMO.Models);