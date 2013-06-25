angular.module('provisioningRoutes', ['ng']).
config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  when('/provisioning/request/:id', {
    templateUrl: 'views/provisioning-request.html',
    controller:  'ProvisioningRequestController'
  }).
  when('/provisioning/request', {
    templateUrl: 'views/provisioning-request.html',
    controller:  'ProvisioningRequestController'
  }).
  when('/provisioning', {
    templateUrl: 'views/provisioning-list.html'
  });
}]);
