

var index_search_timer = null

function poll_for_updated_list(){
  //alert("poll called")
  clearTimeout(index_search_timer);
  index_search_timer = setTimeout(function(){
    var instance_id = $('#instance_id').val();
    var data = {instance_id: instance_id};
    $.ajax({ url: "/campaigns", data: data, type: "GET", success: function(data,textStatus){
      poll_for_updated_list();
      //alert("respone returned test")
    }, error: function(r,t,e){
      alert("test from error")
      alert(r.responseText);
      $('#campaigns_list').html(r.responseText);
    }, dataType: 'script' });
  }, 2000);
};


$(function(){
  poll_for_updated_list();
});
