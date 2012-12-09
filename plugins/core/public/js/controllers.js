function DefaultController($scope){

}

function NavigationController($scope, $http, $route, $routeParams, Summary){
//get site summary
  Summary.query({
    field: 'site'
  }, function(data){
    $scope.sites = data;
  });

//get status summary
  Summary.query({
    field: 'status'
  }, function(data){
    $scope.statuses = data;
  });

//get alert state summary
  Summary.query({
    field: 'alert_state'
  }, function(data){
    $scope.alert_states = $.grep(data, function(el){
      return (el.id !== null);
    });
  });
}