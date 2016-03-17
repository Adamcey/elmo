(function (ns, klass) {

  ns.Response = klass = {}

  klass.init = function(options) {
    // hookup edit location links
    $("a.edit_location_link").click(function(e){ klass.show_location_picker(e); return false; });

    // enable select2 for user selector
    $('#response_user_id').select2({
      ajax: {
        url: options.url,
        dataType: 'json',
        delay: 250,
        data: function (params) {
          return {
            search: params.term,
            page: params.page
          };
        },
        processResults: function (data, page) {
          var results = _.map(data.possible_submitters, function (i) { i.text = i.name; return i; });
          return {
            results: results,
            pagination: { more: data.more }
          };
        },
        cache: true
      }
    });
  }

  // shows the map and location search box
  klass.show_location_picker = function(event) {
    // store existing gps if any
    var location_box = $(event.target).parents("div.control").find("input.qtype_location")[0];
    // create and intialize location picker dialog
    new ELMO.LocationPicker(location_box);
    $('#location-picker-modal').modal('show');

  }

}(ELMO));
