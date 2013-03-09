!function($) {
  $(function() {
    if (this.body.id == 'callback') {
      var query = window.location.search.replace(/^\?/, '');
      if (query === '') return;

      var params = _.object(_.map(query.split('&'), function(param) {
        return param.split('=');
      }));

      if (_.has(params, 'oauth_verifier')) {
        $('input#verifier').val(params['oauth_verifier']);
      }
    }
  });
}(window.jQuery);
